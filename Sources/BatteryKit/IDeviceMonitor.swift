import BatteryCore
import Foundation
import Observation

/// USB arrivals and terminations of Apple mobile devices: the trigger for listing devices.
public protocol IDeviceAttachEvents: Sendable {
    /// One element per USB arrival or termination of an Apple mobile device, plus one right
    /// away when such a device is already present. Watching starts with the call and stops when
    /// the consumer's task is cancelled. Buffering: .bufferingNewest(1).
    func changes() -> AsyncStream<IDeviceAttachChange>
}

public enum IDeviceAttachChange: Sendable, Equatable {
    case arrived, terminated
}

/// The monitor's time: the current date and a sleep until a date. Injectable, so tests run
/// without real waiting.
public struct IDeviceMonitorClock: Sendable {
    public var now: @Sendable () -> Date
    /// Throws `CancellationError` when the sleeping task is cancelled.
    public var sleep: @Sendable (_ until: Date) async throws -> Void

    public init(now: @escaping @Sendable () -> Date, sleep: @escaping @Sendable (_ until: Date) async throws -> Void) {
        self.now = now
        self.sleep = sleep
    }

    /// `Task.sleep(for: max(0, until - now), tolerance: 10 % of that)`, on `ContinuousClock`,
    /// which counts the time the Mac sleeps: a read that came due during sleep runs right after
    /// wake. The tolerance lets macOS coalesce the wake-up with others.
    public static let system = IDeviceMonitorClock(
        now: { Date() },
        sleep: { until in
            let seconds = max(0, until.timeIntervalSinceNow)
            try await Task.sleep(for: .seconds(seconds), tolerance: .seconds(seconds / 10), clock: .continuous)
        })
}

/// iPhones and iPads in the app: which are attached, when to read them, what is remembered and
/// their history.
///
/// Nothing runs while it is disabled (the setting *Read iPhone and iPad batteries* is off by
/// default). Enabled, it watches USB arrivals of Apple mobile devices and lists devices on an
/// arrival, when a Devices page appears, and on Check Again; listing connects to no device.
/// A device on USB is read when it attaches, then as ``IDeviceReadPolicy`` says. Wi-Fi devices are
/// read only on request. One transport call runs at a time; a call that times out stalls all
/// automatic work until the user acts, because a stuck framework call holds the transport's
/// queue and every call behind it would run late, back to back.
///
/// The UDIDs of attached devices and this session's captures stay in memory. Remembered devices
/// (``RememberedDevice``) and their history are in ``DeviceStore``, keyed by ``DeviceKey``.
@MainActor
@Observable
public final class IDeviceMonitor {
    /// The Devices section's rows, sorted by name (``IDeviceRoster``).
    public private(set) var entries: [IDeviceEntry] = []
    /// The remembered devices, as in `devices.json`.
    public private(set) var remembered: [RememberedDevice] = []
    public private(set) var isEnabled = false
    public private(set) var isListing = false
    public private(set) var lastListed: Date?
    /// frameworkUnavailable (permanent for this process) or subscriptionFailed (Check Again
    /// retries); shown on the intro page and as the problem card of every device page.
    public private(set) var unavailable: IDeviceError?
    /// The secret couldn't be read: devices are shown and read, but nothing is remembered.
    public private(set) var cannotRemember = false
    /// A call timed out; automatic work waits for a user action.
    public private(set) var isStalled = false

    @ObservationIgnored private let transport: (any IDeviceTransport)?
    @ObservationIgnored private let store: DeviceStore
    @ObservationIgnored private let makeKeys: @Sendable (Data) -> any DeviceKeyDeriving
    @ObservationIgnored private let attachEvents: (any IDeviceAttachEvents)?
    @ObservationIgnored private let recordsHistory: @MainActor () -> Bool
    @ObservationIgnored private let clock: IDeviceMonitorClock

    @ObservationIgnored private var keys: (any DeviceKeyDeriving)?
    @ObservationIgnored private var sessions: [DeviceKey: IDeviceSession] = [:]
    /// The UDIDs of attached devices, never written anywhere.
    @ObservationIgnored private var udids: [DeviceKey: String] = [:]
    /// This session's latest capture per attached device, for Copy Report.
    @ObservationIgnored private var captures: [DeviceKey: IDeviceCapture] = [:]
    /// Forgotten while attached: not shown, read or remembered again until it detaches.
    @ObservationIgnored private var hidden: Set<DeviceKey> = []
    /// The device whose page is on screen.
    @ObservationIgnored private var visiblePage: DeviceKey?
    /// Bumped when reading is turned off, so results of calls made before are dropped.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var hasSetEnabled = false

    /// The one transport call running.
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var pendingList: ListRequest?
    /// Devices to read, USB first.
    @ObservationIgnored private var pendingReads: [DeviceKey] = []
    /// Pending reads the user asked for: they run even while the monitor is stalled.
    @ObservationIgnored private var userReads: Set<DeviceKey> = []
    /// A USB termination came after the last list started.
    @ObservationIgnored private var terminationPending = false
    /// Attached over USB but missing from one list that followed no termination.
    @ObservationIgnored private var unconfirmedMisses: Set<DeviceKey> = []
    @ObservationIgnored private var attachTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var debounceSawArrival = false
    @ObservationIgnored private var confirmTask: Task<Void, Never>?
    @ObservationIgnored private var scheduleTask: Task<Void, Never>?
    /// Registry saves and history records, in order.
    @ObservationIgnored private var diskWork: Task<Void, Never>?

    private struct ListRequest {
        /// Follows a USB arrival: a list that finds no newly attached USB device is confirmed.
        var afterArrival = false
        /// Check Again, Refresh or Try Again: runs while stalled, and its success clears the stall.
        var isUser = false
        /// Check Again: read every attached device afterwards, Wi-Fi included.
        var readsAll = false
        /// Refresh or Try Again: read these afterwards.
        var reads: Set<DeviceKey> = []

        mutating func merge(_ other: ListRequest) {
            afterArrival = afterArrival || other.afterArrival
            isUser = isUser || other.isUser
            readsAll = readsAll || other.readsAll
            reads.formUnion(other.reads)
        }
    }

    public init(
        transport: (any IDeviceTransport)?, store: DeviceStore,
        makeKeys: @escaping @Sendable (Data) -> any DeviceKeyDeriving,
        attachEvents: (any IDeviceAttachEvents)?,
        recordsHistory: @escaping @MainActor () -> Bool,
        clock: IDeviceMonitorClock = .system
    ) {
        self.transport = transport
        self.store = store
        self.makeKeys = makeKeys
        self.attachEvents = attachEvents
        self.recordsHistory = recordsHistory
        self.clock = clock
    }

    // MARK: - Public interface

    /// Loads the registry, if the file exists, then turns reading on or off. A
    /// ``setEnabled(_:)`` that came first wins over `enabled`.
    public func start(enabled: Bool) async {
        if !hasLoaded {
            hasLoaded = true
            let loaded = (try? await store.load()) ?? []
            // A device read before the registry arrived is kept.
            let known = Set(remembered.map(\.id))
            remembered += loaded.filter { !known.contains($0.id) }
            recomputeEntries()
        }
        if !hasSetEnabled { setEnabled(enabled) }
    }

    /// On: watch USB. Off: stop watching and every scheduled read, discard results still on their
    /// way, and forget what this session knew about attached devices; remembered devices stay,
    /// read-only, as not connected.
    public func setEnabled(_ enabled: Bool) {
        hasSetEnabled = true
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            startWatching()
        } else {
            generation += 1
            for task in [attachTask, debounceTask, confirmTask, scheduleTask] { task?.cancel() }
            attachTask = nil
            debounceTask = nil
            confirmTask = nil
            scheduleTask = nil
            pendingList = nil
            pendingReads = []
            userReads = []
            terminationPending = false
            unconfirmedMisses = []
            sessions = [:]
            udids = [:]
            captures = [:]
            hidden = []
            isListing = false
            recomputeEntries()
        }
        pump()
    }

    /// Battery history was turned on or off: the 5-minute reads start or stop.
    public func historySettingChanged() {
        pump()
    }

    /// A Devices page appeared: list when the last list is older than a minute. This is how
    /// Wi-Fi devices show up.
    public func listIfStale() {
        guard isEnabled, !isStalled, unavailable == nil else { return }
        if let lastListed, clock.now().timeIntervalSince(lastListed) <= IDeviceReadPolicy.listMaxAge { return }
        requestList(ListRequest())
    }

    /// Check Again: list, then read every attached device, Wi-Fi included.
    public func checkAgain() {
        guard isEnabled, !isPermanentlyUnavailable else { return }
        requestList(ListRequest(isUser: true, readsAll: true))
    }

    /// Refresh or Try Again: list, then read this device.
    public func read(_ id: DeviceKey) {
        guard isEnabled, !isPermanentlyUnavailable, !hidden.contains(id) else { return }
        requestList(ListRequest(isUser: true, reads: [id]))
    }

    /// Visibility of a device page; hiding only clears the device it names, because the page
    /// switched away from disappears after the new one appeared.
    public func setPageVisible(_ id: DeviceKey, _ isVisible: Bool) {
        if isVisible {
            visiblePage = id
            // Back from tapping Trust in Finder, say: read now unless a read just succeeded.
            if isEnabled, !isStalled, unavailable == nil, let session = sessions[id], udids[id] != nil,
                !hidden.contains(id),
                IDeviceRoster.connection(of: session, now: clock.now()) == .usb, !session.isReading
            {
                let isRecent = session.lastAttempt.map {
                    clock.now().timeIntervalSince($0) <= IDeviceReadPolicy.visibleInterval
                }
                if session.problem != nil || isRecent != true { enqueueRead(id, isUser: false) }
            }
        } else if visiblePage == id {
            visiblePage = nil
        }
        pump()
    }

    /// Forgets a device: its entry, its history and this session's capture and UDID. A device
    /// that is still attached isn't shown or remembered again until it detaches.
    public func forget(_ id: DeviceKey) async {
        if let session = sessions[id], !session.connections.isEmpty {
            hidden.insert(id)
            var cleared = IDeviceSession()
            cleared.connections = session.connections
            cleared.listedAt = session.listedAt
            sessions[id] = cleared
        } else {
            sessions[id] = nil
        }
        captures[id] = nil
        udids[id] = nil
        pendingReads.removeAll { $0 == id }
        userReads.remove(id)
        remembered.removeAll { $0.id == id }
        recomputeEntries()
        let remaining = remembered
        await onDisk { store in try? await store.forget(id, remaining: remaining) }.value
        pump()
    }

    /// This session's latest capture of the device, for Copy Report; memory only.
    public func capture(for id: DeviceKey) -> IDeviceCapture? {
        captures[id]
    }

    /// Clears every device's history; the registry stays.
    public func clearHistory() async {
        await onDisk { store in try? await store.clearHistory() }.value
    }

    /// Writes pending daily summaries before the app quits.
    public func flushHistory() async {
        await onDisk { store in await store.flush() }.value
    }

    /// The device's history, for the History page and export.
    public func historyStore(for id: DeviceKey) async -> HistoryStore {
        await store.history(for: id)
    }

    public func rememberedDevice(_ id: DeviceKey) -> RememberedDevice? {
        remembered.first { $0.id == id }
    }

    /// Tests: returns when no operation is running or pending and the disk is written.
    func waitUntilIdle() async {
        var quiet = 0
        while quiet < 5 {
            await Task.yield()
            if let operation {
                quiet = 0
                await operation.value
                continue
            }
            let disk = diskWork
            await disk?.value
            if operation != nil || diskWork != disk {
                quiet = 0
                continue
            }
            quiet += 1
        }
    }

    // MARK: - Work queue

    private var isPermanentlyUnavailable: Bool {
        if case .frameworkUnavailable? = unavailable { return true }
        return false
    }

    /// Automatic requests are dropped while stalled or while devices can't be listed.
    private func requestList(_ request: ListRequest) {
        guard isEnabled else { return }
        if !request.isUser, isStalled || unavailable != nil { return }
        if pendingList == nil { pendingList = request } else { pendingList?.merge(request) }
        pump()
    }

    private func enqueueRead(_ key: DeviceKey, isUser: Bool) {
        if isUser { userReads.insert(key) }
        guard !pendingReads.contains(key) else { return }
        if sessions[key]?.connections.contains(.usb) == true {
            let firstOther = pendingReads.firstIndex { sessions[$0]?.connections.contains(.usb) != true }
            pendingReads.insert(key, at: firstOther ?? pendingReads.endIndex)
        } else {
            pendingReads.append(key)
        }
    }

    /// Starts the next piece of work when nothing runs; reschedules when there is none.
    private func pump() {
        guard operation == nil else { return }
        guard isEnabled else {
            scheduleTask?.cancel()
            scheduleTask = nil
            return
        }
        if let request = pendingList, !isStalled || request.isUser {
            pendingList = nil
            runList(request)
            return
        }
        while let index = pendingReads.firstIndex(where: { !isStalled || userReads.contains($0) }) {
            let key = pendingReads.remove(at: index)
            let isUser = userReads.remove(key) != nil
            guard let udid = udids[key], !hidden.contains(key), let transport else { continue }
            runRead(key, udid: udid, isUser: isUser, transport: transport)
            return
        }
        reschedule()
    }

    private func runList(_ request: ListRequest) {
        guard let transport else {
            unavailable = .frameworkUnavailable("No device transport on this platform")
            pump()
            return
        }
        isListing = true
        let generation = generation
        let afterTermination = terminationPending
        terminationPending = false
        operation = Task { [weak self] in
            let result: Result<[IDeviceInfo], any Error>
            do {
                result = .success(try await transport.devices(readingIdentity: false))
            } catch {
                result = .failure(error)
            }
            await self?.finishList(result, request: request, afterTermination: afterTermination, generation: generation)
        }
    }

    private func runRead(_ key: DeviceKey, udid: String, isUser: Bool, transport: any IDeviceTransport) {
        sessions[key]?.isReading = true
        recomputeEntries()
        let generation = generation
        operation = Task { [weak self] in
            let result: Result<IDeviceCapture, any Error>
            do {
                result = .success(try await transport.capture(deviceID: udid))
            } catch {
                result = .failure(error)
            }
            self?.finishRead(key, result: result, generation: generation)
        }
    }

    private func prepareKeys() async {
        guard keys == nil else { return }
        do {
            let secret = try await store.secret()
            keys = keys ?? makeKeys(secret)
        } catch {
            // Never replaced: a new secret would orphan every history. This session works with
            // a secret of its own and remembers nothing.
            cannotRemember = true
            var generator = SystemRandomNumberGenerator()
            keys = keys ?? makeKeys(Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }))
        }
    }

    // MARK: - Results

    private func finishList(
        _ result: Result<[IDeviceInfo], any Error>, request: ListRequest, afterTermination: Bool, generation: Int
    ) async {
        // The secret is read (or created) the first time a device needs a key.
        if generation == self.generation, case .success(let infos) = result, !infos.isEmpty { await prepareKeys() }
        operation = nil
        isListing = false
        guard generation == self.generation else { return pump() }
        switch result {
        case .failure(let error):
            switch error as? IDeviceError {
            case .timedOut?: stall()
            case .frameworkUnavailable?, .subscriptionFailed?: unavailable = error as? IDeviceError
            case .deviceNotFound?, nil: break
            }
        case .success(let infos):
            if case .subscriptionFailed? = unavailable { unavailable = nil }
            isStalled = false
            apply(infos, request: request, afterTermination: afterTermination)
        }
        recomputeEntries()
        pump()
    }

    /// The list's view of which devices are attached, how, and what to read now.
    private func apply(_ infos: [IDeviceInfo], request: ListRequest, afterTermination: Bool) {
        let now = clock.now()
        lastListed = now
        var listed: Set<DeviceKey> = []
        var newlyOnUSB: [DeviceKey] = []
        for info in infos where !info.id.isEmpty {
            guard let key = keys?.key(forIdentifier: info.id) else { continue }
            listed.insert(key)
            udids[key] = info.id
            var session = sessions[key] ?? IDeviceSession()
            if info.connections.contains(.usb), !session.connections.contains(.usb) {
                // A new attachment: a replug reads at once, whatever came before.
                session.lastAttempt = nil
                session.problem = nil
                session.consecutiveFailures = 0
                newlyOnUSB.append(key)
            }
            session.connections = info.connections
            session.listedAt = now
            sessions[key] = session
            unconfirmedMisses.remove(key)
        }

        var needsConfirmation = request.afterArrival && newlyOnUSB.isEmpty
        for (key, session) in sessions where !listed.contains(key) && !session.connections.isEmpty {
            if !session.connections.contains(.usb) || afterTermination || unconfirmedMisses.contains(key) {
                detach(key, at: now)
            } else {
                // usbmuxd may not have caught up; a second list decides.
                unconfirmedMisses.insert(key)
                needsConfirmation = true
            }
        }
        if needsConfirmation { scheduleConfirmation() }

        for key in newlyOnUSB where !hidden.contains(key) { enqueueRead(key, isUser: false) }
        if request.readsAll {
            for key in listed.sorted(by: { $0.rawValue < $1.rawValue }) where !hidden.contains(key) {
                enqueueRead(key, isUser: true)
            }
        }
        for key in request.reads where listed.contains(key) && !hidden.contains(key) {
            enqueueRead(key, isUser: true)
        }
    }

    private func finishRead(_ key: DeviceKey, result: Result<IDeviceCapture, any Error>, generation: Int) {
        operation = nil
        sessions[key]?.isReading = false
        // Turned off or forgotten meanwhile: the result is dropped.
        guard generation == self.generation, !hidden.contains(key), var session = sessions[key] else {
            recomputeEntries()
            return pump()
        }
        let now = clock.now()
        switch result {
        case .failure(let error):
            switch error as? IDeviceError {
            case .deviceNotFound?:
                detach(key, at: now)
                recomputeEntries()
                return pump()
            case .timedOut?:
                session.lastAttempt = now
                session.problem = .transportFailed(.timedOut)
                session.consecutiveFailures += 1
                sessions[key] = session
                stall()
            case .frameworkUnavailable?, .subscriptionFailed?:
                // Shown on every page; nothing automatic runs until the user acts. The attempt
                // still counts, or the device would be due again at once and the read would
                // repeat back to back.
                unavailable = error as? IDeviceError
                session.lastAttempt = now
                session.problem = .transportFailed(.missingResult)
                session.consecutiveFailures += 1
                sessions[key] = session
            case nil:
                session.lastAttempt = now
                session.problem = .transportFailed(.missingResult)
                session.consecutiveFailures += 1
                sessions[key] = session
            }
        case .success(let capture):
            isStalled = false
            if case .subscriptionFailed? = unavailable { unavailable = nil }
            session.lastAttempt = now
            let identity = IDeviceIdentity(capture: capture)
            session.identity = identity
            captures[key] = capture
            session.hasCapture = true
            let battery = capture.problem == nil ? IDeviceBatteryParser.battery(in: capture) : nil
            if let battery {
                session.battery = battery
                session.readAt = now
                session.problem = nil
                session.consecutiveFailures = 0
                sessions[key] = session
                let connection = capture.connection ?? IDeviceRoster.connection(of: session, now: now) ?? .usb
                remember(key, identity: identity, battery: battery, connection: connection, at: now)
            } else {
                // A device is remembered only after a successful battery read, so one that was
                // only charging here leaves no trace on disk.
                session.problem = capture.problem ?? .noBattery
                session.consecutiveFailures += 1
                sessions[key] = session
            }
        }
        recomputeEntries()
        pump()
    }

    private func remember(
        _ key: DeviceKey, identity: IDeviceIdentity, battery: IDeviceBattery, connection: IDeviceConnection,
        at now: Date
    ) {
        guard !cannotRemember else { return }
        if let index = remembered.firstIndex(where: { $0.id == key }) {
            remembered[index] = remembered[index].updated(identity: identity, battery: battery, at: now)
                .seen(over: connection, at: now)
        } else {
            remembered.append(
                RememberedDevice(id: key, identity: identity, battery: battery, at: now).seen(over: connection, at: now)
            )
        }
        let devices = remembered
        let records = recordsHistory()
        onDisk { store in
            try? await store.save(devices)
            guard records else { return }
            let history = await store.history(for: key)
            _ = try? await history.record(HistorySample(device: battery, at: now))
            try? await history.record(HistoryDay(device: battery, day: HistoryDay.key(for: now)), at: now)
        }
    }

    /// The device is gone: its UDID and capture are dropped, its problem cleared, and a
    /// remembered device's last sighting saved. A device that was never remembered disappears.
    private func detach(_ key: DeviceKey, at now: Date) {
        guard var session = sessions[key] else { return }
        let lastSeen = session.connections.contains(.usb) ? now : (session.listedAt ?? now)
        let connection = session.connections.first
        udids[key] = nil
        captures[key] = nil
        hidden.remove(key)
        unconfirmedMisses.remove(key)
        pendingReads.removeAll { $0 == key }
        userReads.remove(key)
        if let index = remembered.firstIndex(where: { $0.id == key }) {
            session.connections = []
            session.problem = nil
            session.consecutiveFailures = 0
            session.hasCapture = false
            sessions[key] = session
            if let connection, !cannotRemember {
                remembered[index] = remembered[index].seen(over: connection, at: lastSeen)
                let devices = remembered
                onDisk { store in try? await store.save(devices) }
            }
        } else {
            sessions[key] = nil
        }
    }

    private func stall() {
        isStalled = true
        if pendingList?.isUser != true { pendingList = nil }
        pendingReads.removeAll { !userReads.contains($0) }
        scheduleTask?.cancel()
        scheduleTask = nil
    }

    private func recomputeEntries() {
        let next = IDeviceRoster.entries(remembered: remembered, sessions: sessions, hidden: hidden, now: clock.now())
        if next != entries { entries = next }
    }

    @discardableResult
    private func onDisk(_ work: @escaping @Sendable (DeviceStore) async -> Void) -> Task<Void, Never> {
        let previous = diskWork
        let store = store
        let task = Task {
            await previous?.value
            await work(store)
        }
        diskWork = task
        return task
    }

    // MARK: - Timers

    private func startWatching() {
        guard let attachEvents, attachTask == nil else { return }
        attachTask = Task { [weak self] in
            for await change in attachEvents.changes() {
                self?.attachChanged(change)
            }
        }
    }

    /// Each USB event restarts the wait. After a termination the list detaches a missing USB
    /// device at once; after an arrival a list that finds no newly attached USB device is
    /// confirmed, so a cable re-seated within one wait is read again once usbmuxd catches up.
    private func attachChanged(_ change: IDeviceAttachChange) {
        guard isEnabled else { return }
        switch change {
        case .arrived: debounceSawArrival = true
        case .terminated: terminationPending = true
        }
        debounceTask?.cancel()
        let until = clock.now().addingTimeInterval(IDeviceReadPolicy.attachDebounce)
        debounceTask = Task { [weak self, clock] in
            do { try await clock.sleep(until) } catch { return }
            self?.debounceEnded()
        }
    }

    private func debounceEnded() {
        debounceTask = nil
        let afterArrival = debounceSawArrival
        debounceSawArrival = false
        requestList(ListRequest(afterArrival: afterArrival))
    }

    private func scheduleConfirmation() {
        guard confirmTask == nil else { return }
        let until = clock.now().addingTimeInterval(IDeviceReadPolicy.confirmDelay)
        confirmTask = Task { [weak self, clock] in
            do { try await clock.sleep(until) } catch { return }
            self?.confirmTask = nil
            self?.requestList(ListRequest())
        }
    }

    /// One task sleeps until the next due read or Wi-Fi expiry; recreated after every change.
    /// Nothing is scheduled while stalled or while devices can't be listed or read: only the
    /// user's Check Again, Refresh or Try Again starts work then.
    private func reschedule() {
        scheduleTask?.cancel()
        scheduleTask = nil
        guard isEnabled, !isStalled, unavailable == nil else { return }
        let now = clock.now()
        // Only devices that can be read: hidden ones and ones without a UDID never come due.
        let candidates = sessions.filter { udids[$0.key] != nil && !hidden.contains($0.key) }
        guard
            let wake = IDeviceReadPolicy.nextWake(
                candidates, visible: visiblePage, recordsHistory: recordsHistory(), now: now)
        else { return }
        scheduleTask = Task { [weak self, clock] in
            do { try await clock.sleep(wake) } catch { return }
            self?.scheduleFired()
        }
    }

    private func scheduleFired() {
        scheduleTask = nil
        guard isEnabled, !isStalled, unavailable == nil else { return }
        let now = clock.now()
        for (key, session) in sessions
        where !session.connections.isEmpty && IDeviceRoster.connection(of: session, now: now) == nil {
            // A Wi-Fi sighting expired.
            detach(key, at: now)
        }
        let history = recordsHistory()
        for (key, session) in sessions where udids[key] != nil && !hidden.contains(key) {
            let due = IDeviceReadPolicy.nextRead(
                session, isVisible: key == visiblePage, recordsHistory: history, now: now)
            if let due, due <= now { enqueueRead(key, isUser: false) }
        }
        recomputeEntries()
        pump()
    }
}

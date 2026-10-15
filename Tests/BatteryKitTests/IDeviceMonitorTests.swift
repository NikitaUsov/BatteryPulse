import BatteryCore
import Foundation
import Testing

@testable import BatteryKit

// MARK: - Fakes

/// An ``IDeviceTransport`` that answers at once from a script and logs every call. Captures are
/// built in code; every UDID is SYNTHETIC.
actor ScriptedTransport: IDeviceTransport {
    private var attached: [IDeviceInfo] = []
    private var listErrors: [IDeviceError] = []
    private var scripts: [String: [Result<IDeviceCapture, IDeviceError>]] = [:]
    private var defaults: [String: IDeviceCapture] = [:]
    private(set) var calls: [String] = []
    private var isHolding = false
    private var held: [CheckedContinuation<Void, Never>] = []
    private var callWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func devices(readingIdentity: Bool) async throws -> [IDeviceInfo] {
        log("list")
        if !listErrors.isEmpty { throw listErrors.removeFirst() }
        return attached
    }

    func capture(deviceID: String) async throws -> IDeviceCapture {
        log("capture " + deviceID.suffix(4))
        if isHolding { await withCheckedContinuation { held.append($0) } }
        guard attached.contains(where: { $0.id == deviceID }) else { throw IDeviceError.deviceNotFound }
        if var script = scripts[deviceID], !script.isEmpty {
            let next = script.removeFirst()
            scripts[deviceID] = script
            return try next.get()
        }
        guard let capture = defaults[deviceID] else { throw IDeviceError.deviceNotFound }
        return capture
    }

    func attach(_ udid: String, _ connections: [IDeviceConnection] = [.usb], capture: IDeviceCapture? = nil) {
        attached.removeAll { $0.id == udid }
        attached.append(IDeviceInfo(id: udid, connections: connections))
        if let capture { defaults[udid] = capture }
    }

    func detachAll() {
        attached = []
    }

    func failLists(_ errors: [IDeviceError]) {
        listErrors = errors
    }

    func script(_ udid: String, _ results: [Result<IDeviceCapture, IDeviceError>]) {
        scripts[udid] = results
    }

    func hold() {
        isHolding = true
    }

    func release() {
        isHolding = false
        for continuation in held { continuation.resume() }
        held = []
    }

    func count(_ prefix: String) -> Int {
        calls.filter { $0.hasPrefix(prefix) }.count
    }

    func waitForCalls(_ count: Int) async {
        guard calls.count < count else { return }
        await withCheckedContinuation { callWaiters.append((count, $0)) }
    }

    private func log(_ call: String) {
        calls.append(call)
        let ready = callWaiters.filter { $0.count <= calls.count }
        callWaiters.removeAll { $0.count <= calls.count }
        for waiter in ready { waiter.continuation.resume() }
    }
}

/// USB events the test sends by hand.
final class FakeAttachEvents: IDeviceAttachEvents, @unchecked Sendable {
    // `@unchecked`: the stored values are guarded by `lock`.
    private let lock = NSLock()
    private let initialArrival: Bool
    private var continuation: AsyncStream<IDeviceAttachChange>.Continuation?
    private var callCount = 0

    init(initialArrival: Bool) {
        self.initialArrival = initialArrival
    }

    var calls: Int { lock.withLock { callCount } }

    func changes() -> AsyncStream<IDeviceAttachChange> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: IDeviceAttachChange.self, bufferingPolicy: .bufferingNewest(1))
        lock.withLock {
            callCount += 1
            self.continuation = continuation
        }
        if initialArrival { continuation.yield(.arrived) }
        return stream
    }

    func send(_ change: IDeviceAttachChange) {
        _ = lock.withLock { continuation }?.yield(change)
    }
}

/// Time that moves only when the test says so. Sleepers wait on the main actor, so a sleeper
/// that `advance` wakes runs before the test continues past a `Task.yield()`.
@MainActor
final class ManualClock {
    private let time: LockedValue<Date>
    private var sleepers: [(id: UUID, until: Date, continuation: CheckedContinuation<Void, any Error>)] = []
    private var waiters: [(isReady: @MainActor (ManualClock) -> Bool, continuation: CheckedContinuation<Void, Never>)] =
        []

    init(_ start: Date) {
        time = LockedValue(start)
    }

    var now: Date { time.get() }

    /// The earliest time a sleeper waits for.
    var nextWake: Date? { sleepers.map(\.until).min() }
    var sleeperCount: Int { sleepers.count }

    var monitorClock: IDeviceMonitorClock {
        let time = time
        return IDeviceMonitorClock(
            now: { time.get() },
            sleep: { @MainActor [self] until in try await self.sleep(until: until) })
    }

    func sleep(until: Date) async throws {
        guard until > now else { return try Task.checkCancellation() }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                sleepers.append((id, until, continuation))
                resumeReadyWaiters()
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return }
        sleepers.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    func advance(to date: Date) {
        time.set(date)
        let due = sleepers.filter { $0.until <= date }.sorted { $0.until < $1.until }
        sleepers.removeAll { $0.until <= date }
        for sleeper in due { sleeper.continuation.resume() }
    }

    func advance(by seconds: TimeInterval) {
        advance(to: now.addingTimeInterval(seconds))
    }

    /// Returns once at least `count` sleepers wait: the monitor has armed its timers.
    func waitForSleepers(_ count: Int) async {
        await waitUntil { $0.sleepers.count >= count }
    }

    /// Returns once a sleeper waits for exactly `date`, such as a debounce just armed.
    func waitForSleeper(until date: Date) async {
        await waitUntil { $0.sleepers.contains { $0.until == date } }
    }

    private func waitUntil(_ isReady: @escaping @MainActor (ManualClock) -> Bool) async {
        guard !isReady(self) else { return }
        await withCheckedContinuation { waiters.append((isReady, $0)) }
    }

    private func resumeReadyWaiters() {
        let ready = waiters.filter { $0.isReady(self) }
        waiters.removeAll { $0.isReady(self) }
        for waiter in ready { waiter.continuation.resume() }
    }
}

/// Keys without CryptoKit: "k" and the UDID's last four characters.
struct PrefixKeyDeriver: DeviceKeyDeriving {
    func key(forIdentifier udid: String) -> DeviceKey {
        DeviceKey("k" + udid.suffix(4).lowercased()) ?? .demo
    }
}

/// Captures built in code, with a small SYNTHETIC `AppleSmartBattery` reply.
enum TestCaptures {
    static func battery(percent: Int) -> PropertyDictionary {
        [
            "DesignCapacity": .int(5030), "NominalChargeCapacity": .int(4800), "AppleRawMaxCapacity": .int(4922),
            "AppleRawCurrentCapacity": .int(3151), "CycleCount": .int(278), "IsCharging": .bool(true),
            "ExternalConnected": .bool(true), "Voltage": .int(4137), "Amperage": .int(2108),
            "Temperature": .int(3650), "CurrentCapacity": .int(Int64(percent)), "MaxCapacity": .int(100),
        ]
    }

    static func device(_ udid: String, name: String, connection: IDeviceConnection) -> PropertyDictionary {
        [
            "DeviceName": .string(name), "DeviceClass": .string("iPhone"), "ProductType": .string("iPhone18,2"),
            "ProductVersion": .string("27.0.1"), "Connection": .string(connection.rawValue),
            "UniqueDeviceID": .string(udid),
        ]
    }

    static func ok(
        _ udid: String, name: String = "Phone", percent: Int = 65, connection: IDeviceConnection = .usb
    ) -> IDeviceCapture {
        let reply: PropertyDictionary = [
            "Status": .string("Success"),
            "Diagnostics": .dictionary(["IORegistry": .dictionary(battery(percent: percent))]),
        ]
        return IDeviceCapture(
            device: device(udid, name: name, connection: connection),
            isPaired: true,
            lockdownBattery: ["BatteryCurrentCapacity": .int(Int64(percent))],
            exchanges: [
                .init(request: DiagnosticsRelay.registryRequest(entryClass: "AppleSmartBattery"), reply: reply)
            ],
            steps: [
                .init(.connect, .success), .init(.validatePairing, .success), .init(.startSession, .success),
                .init(.startService, .success), .init(.closeService, .success), .init(.stopSession, .success),
                .init(.disconnect, .success),
            ])
    }

    /// A read that stopped at the session: locked (`passwordProtected`) or not trusted.
    static func failed(_ udid: String, name: String = "Phone", session: IDeviceStatus) -> IDeviceCapture {
        IDeviceCapture(
            device: device(udid, name: name, connection: .usb),
            isPaired: session != .invalidHostID,
            steps: [
                .init(.connect, .success), .init(.validatePairing, .success), .init(.startSession, session),
                .init(.disconnect, .success),
            ])
    }
}

@MainActor
final class Flag {
    var value: Bool

    init(_ value: Bool) {
        self.value = value
    }
}

/// A monitor wired to the fakes, in a temporary store directory.
@MainActor
struct MonitorHarness {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    let directory: URL
    let transport = ScriptedTransport()
    let events: FakeAttachEvents
    let clock = ManualClock(start)
    let history: Flag
    let monitor: IDeviceMonitor

    init(initialArrival: Bool = true, recordsHistory: Bool = true, transport: Bool = true) {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Devices")
        events = FakeAttachEvents(initialArrival: initialArrival)
        history = Flag(recordsHistory)
        let flag = history
        monitor = IDeviceMonitor(
            transport: transport ? self.transport : nil,
            store: DeviceStore(directory: directory, now: { .distantFuture }),
            makeKeys: { _ in PrefixKeyDeriver() },
            attachEvents: events,
            recordsHistory: { flag.value },
            clock: clock.monitorClock)
    }

    func cleanUp() {
        monitor.setEnabled(false)
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }

    /// Starts enabled and lets the initial USB scan (if any) list and read.
    func startWithInitialScan() async {
        await monitor.start(enabled: true)
        await clock.waitForSleeper(until: clock.now.addingTimeInterval(IDeviceReadPolicy.attachDebounce))
        await advance(by: IDeviceReadPolicy.attachDebounce)
    }

    func advance(by seconds: TimeInterval) async {
        clock.advance(by: seconds)
        await monitor.waitUntilIdle()
    }

    func settle() async {
        await monitor.waitUntilIdle()
    }

    /// Sends a USB event and waits until the monitor has armed its debounce.
    func deliver(_ change: IDeviceAttachChange) async {
        let debounceEnd = clock.now.addingTimeInterval(IDeviceReadPolicy.attachDebounce)
        events.send(change)
        await clock.waitForSleeper(until: debounceEnd)
    }

    /// Sends a USB event and lets its debounce end.
    func send(_ change: IDeviceAttachChange) async {
        await deliver(change)
        await advance(by: IDeviceReadPolicy.attachDebounce)
    }

    func registry() async throws -> [RememberedDevice] {
        try await DeviceStore(directory: directory).load()
    }

    func samples(_ key: DeviceKey) async throws -> [HistorySample] {
        try await DeviceStore(directory: directory, now: { .distantFuture }).history(for: key)
            .samples(since: .distantPast)
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path)
    }

    func count(_ prefix: String) async -> Int {
        await transport.count(prefix)
    }
}

// MARK: - Tests

/// A hang would hold CI for hours: every test gets a minute.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct IDeviceMonitorTests {
    static let phone = "00008150-00000000000A801C"
    static let pad = "00008030-00000000000B4D5E"
    static let phoneKey = DeviceKey("k801c") ?? .demo
    static let padKey = DeviceKey("k4d5e") ?? .demo

    private func phoneAttached(_ h: MonitorHarness, name: String = "Phone") async {
        await h.transport.attach(Self.phone, capture: TestCaptures.ok(Self.phone, name: name))
    }

    @Test func disabledMakesNoCallsAndNoFiles() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.monitor.start(enabled: false)
        h.monitor.listIfStale()
        h.monitor.checkAgain()
        h.monitor.read(Self.phoneKey)
        h.monitor.setPageVisible(Self.phoneKey, true)
        await h.settle()
        #expect(await h.transport.calls.isEmpty)
        #expect(h.events.calls == 0)
        #expect(h.clock.sleeperCount == 0)
        #expect(!FileManager.default.fileExists(atPath: h.directory.path))
        #expect(!h.monitor.isEnabled)
    }

    @Test func enabledWithoutUSBDeviceLoadsNothing() async throws {
        let h = MonitorHarness(initialArrival: false)
        defer { h.cleanUp() }
        await h.monitor.start(enabled: true)
        await h.settle()
        await h.advance(by: 3600)
        #expect(h.events.calls == 1)
        #expect(await h.transport.calls.isEmpty)
        #expect(h.clock.sleeperCount == 0)
        #expect(!FileManager.default.fileExists(atPath: h.directory.path))
    }

    @Test func initialScanListsAndReadsUSB() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(await h.transport.calls == ["list", "capture 801C"])
        let entry = try #require(h.monitor.entries.first)
        #expect(h.monitor.entries.count == 1)
        #expect(entry.id == Self.phoneKey)
        #expect(entry.isRemembered)
        #expect(entry.name == "Phone")
        #expect(entry.connection == .usb)
        #expect(entry.battery?.chargePercent == 65)
        #expect(entry.hasCapture)
        #expect(h.monitor.capture(for: Self.phoneKey) != nil)
        let registry = try await h.registry()
        #expect(registry.map(\.id) == [Self.phoneKey])
        #expect(registry.first?.lastConnection == .usb)
        #expect(try await h.samples(Self.phoneKey).count == 1)
        let days = try await DeviceStore(directory: h.directory).history(for: Self.phoneKey).dailySummaries()
        #expect(days.count == 1)
        #expect(days.first?.healthPercent == 95.4)
        #expect(h.exists("key"))
        // The next read in 5 minutes.
        #expect(h.clock.nextWake == h.clock.now.addingTimeInterval(300))
    }

    @Test func attachBurstCoalescesIntoOneList() async throws {
        let h = MonitorHarness(initialArrival: false)
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.monitor.start(enabled: true)
        await h.settle()
        for _ in 0..<5 {
            await h.deliver(.arrived)
            await h.advance(by: 0.2)
        }
        #expect(await h.transport.calls.isEmpty)
        await h.advance(by: IDeviceReadPolicy.attachDebounce)
        #expect(await h.count("list") == 1)
        #expect(await h.count("capture") == 1)
    }

    @Test func arrivalWithoutDeviceListsOnceMore() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await h.startWithInitialScan()
        #expect(await h.transport.calls == ["list"])
        #expect(!FileManager.default.fileExists(atPath: h.directory.path), "no key for an empty list")
        // usbmuxd catches up.
        await phoneAttached(h)
        await h.advance(by: IDeviceReadPolicy.confirmDelay)
        #expect(await h.transport.calls == ["list", "list", "capture 801C"])
        await h.advance(by: 30)
        #expect(await h.count("list") == 2)
    }

    @Test func usbMissWithoutTerminationIsConfirmed() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        await h.transport.detachAll()
        await h.advance(by: 61)
        h.monitor.listIfStale()
        await h.settle()
        #expect(await h.count("list") == 2)
        #expect(h.monitor.entries.first?.connection == .usb, "one miss isn't enough")
        await h.advance(by: IDeviceReadPolicy.confirmDelay)
        #expect(await h.count("list") == 3)
        #expect(h.monitor.entries.first?.connection == nil)
        #expect(h.monitor.entries.first?.isRemembered == true)
        #expect(h.monitor.capture(for: Self.phoneKey) == nil)
    }

    @Test func terminationThenMissDetachesAtOnce() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        await h.transport.detachAll()
        await h.send(.terminated)
        #expect(await h.count("list") == 2)
        #expect(h.monitor.entries.first?.connection == nil)
        await h.advance(by: 30)
        #expect(await h.count("list") == 2, "no confirming list")
    }

    @Test func wifiDeviceIsListedButNotReadOrShownUntilChecked() async throws {
        let h = MonitorHarness(initialArrival: false)
        defer { h.cleanUp() }
        await h.transport.attach(
            Self.pad, [.wifi], capture: TestCaptures.ok(Self.pad, name: "Tablet", connection: .wifi))
        await h.monitor.start(enabled: true)
        h.monitor.listIfStale()
        await h.settle()
        #expect(await h.transport.calls == ["list"])
        #expect(h.monitor.entries.isEmpty)
        #expect(h.monitor.lastListed == h.clock.now)
        // Listing again within a minute does nothing; Wi-Fi is never read by itself.
        h.monitor.listIfStale()
        await h.advance(by: 3600)
        #expect(await h.transport.calls == ["list"])
    }

    @Test func checkAgainReadsWiFiToo() async throws {
        let h = MonitorHarness(initialArrival: false)
        defer { h.cleanUp() }
        await h.transport.attach(
            Self.pad, [.wifi], capture: TestCaptures.ok(Self.pad, name: "Tablet", connection: .wifi))
        await h.monitor.start(enabled: true)
        h.monitor.checkAgain()
        await h.settle()
        #expect(await h.transport.calls == ["list", "capture 4D5E"])
        let entry = try #require(h.monitor.entries.first)
        #expect(entry.name == "Tablet")
        #expect(entry.connection == .wifi)
        #expect(try await h.registry().first?.lastConnection == .wifi)
        // The sighting lasts 10 minutes; nothing reads it meanwhile.
        #expect(h.clock.nextWake == h.clock.now.addingTimeInterval(IDeviceReadPolicy.wifiPresenceLifetime))
        await h.advance(by: IDeviceReadPolicy.wifiPresenceLifetime)
        #expect(h.monitor.entries.first?.connection == nil)
        #expect(await h.count("capture") == 1)
    }

    @Test func lockedIsRetriedAt20And60ThenEvery5Minutes() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        let locked = Result<IDeviceCapture, IDeviceError>.success(
            TestCaptures.failed(Self.phone, session: .passwordProtected))
        await h.transport.script(Self.phone, [locked, locked, locked])
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(await h.count("capture") == 1)
        #expect(h.monitor.entries.first?.problem == .locked)
        #expect(h.monitor.entries.first?.name == "Phone", "the lockdown name")
        await h.advance(by: 19)
        #expect(await h.count("capture") == 1)
        await h.advance(by: 1)
        #expect(await h.count("capture") == 2)
        await h.advance(by: 59)
        #expect(await h.count("capture") == 2)
        await h.advance(by: 1)
        #expect(await h.count("capture") == 3)
        await h.advance(by: 299)
        #expect(await h.count("capture") == 3)
        await h.advance(by: 1)
        #expect(await h.count("capture") == 4)
        #expect(h.monitor.entries.first?.problem == nil)
        #expect(h.monitor.entries.first?.battery?.chargePercent == 65)
    }

    @Test func notTrustedIsNotRetriedAfterQuickRetries() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        let untrusted = TestCaptures.failed(Self.phone, session: .invalidHostID)
        await h.transport.attach(Self.phone, capture: untrusted)
        await h.startWithInitialScan()
        await h.advance(by: 20)
        await h.advance(by: 60)
        #expect(await h.count("capture") == 3)
        #expect(h.clock.nextWake == nil)
        await h.advance(by: 3600)
        #expect(await h.count("capture") == 3)
        // The page on screen doesn't bring the reads back either.
        h.monitor.setPageVisible(Self.phoneKey, true)
        await h.settle()
        #expect(await h.count("capture") == 4, "appearing reads once after a failure")
        await h.advance(by: 3600)
        #expect(await h.count("capture") == 4)
    }

    @Test func untrustedDeviceIsNotRemembered() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        let untrusted = TestCaptures.failed(Self.phone, name: "Owner's iPhone", session: .invalidHostID)
        await h.transport.attach(Self.phone, capture: untrusted)
        await h.startWithInitialScan()
        let entry = try #require(h.monitor.entries.first)
        #expect(!entry.isRemembered)
        #expect(entry.name == "Owner's iPhone")
        #expect(entry.battery == nil)
        #expect(entry.problem == .notTrusted(.invalidHostID))
        #expect(!h.exists("devices.json"))
        #expect(!h.exists(Self.phoneKey.rawValue))
        // Unplugged, it leaves no row behind.
        await h.transport.detachAll()
        await h.send(.terminated)
        #expect(h.monitor.entries.isEmpty)
    }

    @Test func replugReadsAtOnce() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        await h.transport.detachAll()
        await h.send(.terminated)
        await h.advance(by: 30)
        await phoneAttached(h)
        await h.send(.arrived)
        #expect(await h.count("capture") == 2)
        #expect(h.monitor.entries.first?.connection == .usb)
    }

    @Test func detachKeepsRememberedDeviceSetsLastSeenAndClearsProblem() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        await h.transport.script(
            Self.phone, [.success(TestCaptures.failed(Self.phone, session: .passwordProtected))])
        h.monitor.read(Self.phoneKey)
        await h.settle()
        #expect(h.monitor.entries.first?.problem == .locked)
        await h.advance(by: 10)
        await h.transport.detachAll()
        await h.send(.terminated)
        let entry = try #require(h.monitor.entries.first)
        #expect(entry.isRemembered)
        #expect(entry.connection == nil)
        #expect(entry.problem == nil)
        #expect(entry.battery?.chargePercent == 65)
        #expect(entry.lastSeen == h.clock.now)
        #expect(
            try await h.registry().first?.lastSeen.timeIntervalSince1970
                == h.clock.now.timeIntervalSince1970.rounded(.down))
        #expect(h.monitor.capture(for: Self.phoneKey) == nil)
        #expect(h.clock.nextWake == nil, "nothing to read")
    }

    @Test func forgetWhileConnectedStaysForgottenUntilDetach() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(h.exists(Self.phoneKey.rawValue))
        await h.monitor.forget(Self.phoneKey)
        #expect(h.monitor.entries.isEmpty)
        #expect(h.monitor.remembered.isEmpty)
        #expect(try await h.registry().isEmpty)
        #expect(!h.exists(Self.phoneKey.rawValue))
        #expect(h.monitor.capture(for: Self.phoneKey) == nil)
        h.monitor.checkAgain()
        await h.advance(by: 600)
        #expect(await h.count("capture") == 1)
        #expect(h.monitor.entries.isEmpty)
        await h.transport.detachAll()
        await h.send(.terminated)
        await phoneAttached(h)
        await h.send(.arrived)
        #expect(await h.count("capture") == 2)
        #expect(h.monitor.entries.map(\.id) == [Self.phoneKey])
        #expect(try await h.registry().count == 1)
    }

    @Test func forgetDropsLateResult() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        await h.transport.hold()
        h.monitor.read(Self.phoneKey)
        await h.transport.waitForCalls(4)
        await h.monitor.forget(Self.phoneKey)
        await h.transport.release()
        await h.settle()
        #expect(h.monitor.entries.isEmpty)
        #expect(try await h.registry().isEmpty)
        #expect(!h.exists(Self.phoneKey.rawValue))
        #expect(h.monitor.capture(for: Self.phoneKey) == nil)
    }

    @Test func disableDropsInFlightResult() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        let firstRead = try #require(h.monitor.entries.first?.readAt)
        await h.transport.attach(Self.phone, capture: TestCaptures.ok(Self.phone, percent: 80))
        await h.transport.hold()
        await h.advance(by: 30)
        h.monitor.read(Self.phoneKey)
        await h.transport.waitForCalls(4)
        h.monitor.setEnabled(false)
        await h.transport.release()
        await h.settle()
        let entry = try #require(h.monitor.entries.first)
        #expect(entry.battery?.chargePercent == 65)
        #expect(entry.readAt == firstRead)
        #expect(entry.connection == nil, "remembered, read-only, not connected")
        #expect(h.monitor.capture(for: Self.phoneKey) == nil)
        #expect(try await h.samples(Self.phoneKey).count == 1)
        #expect(h.clock.sleeperCount == 0)
    }

    @Test func historyOffSkipsSamplesAndBackgroundReads() async throws {
        let h = MonitorHarness(recordsHistory: false)
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(try await h.registry().count == 1)
        #expect(!h.exists(Self.phoneKey.rawValue))
        #expect(h.clock.nextWake == nil)
        await h.advance(by: 3600)
        #expect(await h.count("capture") == 1)
    }

    @Test func historySettingChangedReschedules() async throws {
        let h = MonitorHarness(recordsHistory: false)
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        let readAt = try #require(h.monitor.entries.first?.readAt)
        #expect(h.clock.nextWake == nil)
        h.history.value = true
        h.monitor.historySettingChanged()
        await h.settle()
        #expect(h.clock.nextWake == readAt.addingTimeInterval(300))
        h.history.value = false
        h.monitor.historySettingChanged()
        await h.settle()
        #expect(h.clock.nextWake == nil)
    }

    @Test func visiblePageReadsEveryMinute() async throws {
        let h = MonitorHarness(recordsHistory: false)
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        h.monitor.setPageVisible(Self.phoneKey, true)
        await h.settle()
        #expect(await h.count("capture") == 1, "just read")
        await h.advance(by: 60)
        #expect(await h.count("capture") == 2)
        await h.advance(by: 60)
        #expect(await h.count("capture") == 3)
        h.monitor.setPageVisible(Self.phoneKey, false)
        await h.settle()
        await h.advance(by: 600)
        #expect(await h.count("capture") == 3)
    }

    @Test func pageSwitchKeepsNewPageVisible() async throws {
        let h = MonitorHarness(recordsHistory: false)
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.transport.attach(Self.pad, capture: TestCaptures.ok(Self.pad, name: "Tablet"))
        await h.startWithInitialScan()
        #expect(await h.count("capture") == 2)
        h.monitor.setPageVisible(Self.phoneKey, true)
        // The detail crossfades: the new page appears before the old one goes.
        h.monitor.setPageVisible(Self.padKey, true)
        h.monitor.setPageVisible(Self.phoneKey, false)
        await h.settle()
        await h.advance(by: 60)
        #expect(await h.count("capture 4D5E") == 2)
        #expect(await h.count("capture 801C") == 1)
    }

    @Test func pageAppearReadsAfterFailedAttempt() async throws {
        let h = MonitorHarness(recordsHistory: false)
        defer { h.cleanUp() }
        await h.transport.script(
            Self.phone, [.success(TestCaptures.failed(Self.phone, session: .passwordProtected))])
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(h.monitor.entries.first?.problem == .locked)
        await h.advance(by: 5)
        h.monitor.setPageVisible(Self.phoneKey, true)
        await h.settle()
        #expect(await h.count("capture") == 2)
        #expect(h.monitor.entries.first?.problem == nil)
    }

    @Test func timeoutStallsAutomaticWorkUntilUserAction() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await h.transport.script(Self.phone, [.failure(.timedOut(seconds: 60))])
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(h.monitor.isStalled)
        #expect(h.monitor.entries.first?.problem == .transportFailed(.timedOut))
        #expect(h.clock.nextWake == nil)
        // USB events, pages and the clock start nothing.
        await h.send(.arrived)
        h.monitor.listIfStale()
        h.monitor.setPageVisible(Self.phoneKey, true)
        await h.advance(by: 3600)
        #expect(await h.transport.calls == ["list", "capture 801C"])
        // Try Again works, and a call that returns ends the stall.
        h.monitor.read(Self.phoneKey)
        await h.settle()
        #expect(!h.monitor.isStalled)
        #expect(h.monitor.entries.first?.problem == nil)
        #expect(h.clock.nextWake != nil)
    }

    @Test func deviceNotFoundMeansDetached() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        await h.transport.script(Self.phone, [.failure(.deviceNotFound)])
        h.monitor.read(Self.phoneKey)
        await h.settle()
        let entry = try #require(h.monitor.entries.first)
        #expect(entry.connection == nil)
        #expect(entry.problem == nil)
        #expect(!h.monitor.isStalled)
    }

    @Test func frameworkUnavailableIsReportedNotRetried() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await h.transport.failLists([.frameworkUnavailable("missing"), .frameworkUnavailable("missing")])
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(h.monitor.unavailable == .frameworkUnavailable("missing"))
        await h.send(.arrived)
        h.monitor.checkAgain()
        h.monitor.listIfStale()
        await h.advance(by: 3600)
        #expect(await h.transport.calls == ["list"])
    }

    @Test func subscriptionFailureIsRetriedByCheckAgain() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await h.transport.failLists([.subscriptionFailed(.noResources)])
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(h.monitor.unavailable == .subscriptionFailed(.noResources))
        h.monitor.listIfStale()
        await h.settle()
        #expect(await h.count("list") == 1)
        h.monitor.checkAgain()
        await h.settle()
        #expect(h.monitor.unavailable == nil)
        #expect(await h.transport.calls == ["list", "list", "capture 801C"])
    }

    /// A read can fail to subscribe at once; the device mustn't come due again right away, or
    /// the reads would repeat back to back.
    @Test func subscriptionFailureOnReadIsNotRepeated() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await h.transport.script(Self.phone, [.failure(.subscriptionFailed(.noResources))])
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(h.monitor.unavailable == .subscriptionFailed(.noResources))
        #expect(h.clock.nextWake == nil)
        h.monitor.setPageVisible(Self.phoneKey, true)
        await h.advance(by: 3600)
        #expect(await h.transport.calls == ["list", "capture 801C"])
        // Try Again lists, which clears the problem, and reads.
        h.monitor.read(Self.phoneKey)
        await h.settle()
        #expect(h.monitor.unavailable == nil)
        #expect(h.monitor.entries.first?.problem == nil)
        #expect(await h.transport.calls == ["list", "capture 801C", "list", "capture 801C"])
        #expect(h.clock.nextWake != nil)
    }

    @Test func secretErrorShowsButRemembersNothing() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        try FileManager.default.createDirectory(
            at: h.directory.appendingPathComponent("key"), withIntermediateDirectories: true)
        await phoneAttached(h)
        await h.startWithInitialScan()
        #expect(h.monitor.cannotRemember)
        let entry = try #require(h.monitor.entries.first)
        #expect(!entry.isRemembered)
        #expect(entry.battery?.chargePercent == 65)
        #expect(!h.exists("devices.json"))
        #expect(!h.exists(Self.phoneKey.rawValue))
        var isDirectory: ObjCBool = false
        #expect(
            FileManager.default.fileExists(
                atPath: h.directory.appendingPathComponent("key").path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test func rememberedDevicesLoadAtStartEvenWhenOff() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        let device = RememberedDevice(
            id: Self.padKey, identity: IDeviceIdentity(name: "Tablet", deviceClass: "iPad"),
            battery: IDeviceBattery(chargePercent: 40), at: MonitorHarness.start)
        try await DeviceStore(directory: h.directory).save([device])
        await h.monitor.start(enabled: false)
        #expect(h.monitor.entries.map(\.id) == [Self.padKey])
        #expect(h.monitor.entries.first?.connection == nil)
        #expect(await h.transport.calls.isEmpty)
    }

    @Test func udidNeverReachesDisk() async throws {
        let h = MonitorHarness()
        defer { h.cleanUp() }
        await phoneAttached(h)
        await h.startWithInitialScan()
        await h.advance(by: 300)
        await h.transport.detachAll()
        await h.send(.terminated)
        await h.monitor.flushHistory()
        let enumerator = try #require(FileManager.default.enumerator(at: h.directory, includingPropertiesForKeys: nil))
        // `allObjects`: iterating an enumerator with for-in is unavailable in async code on macOS.
        let urls = enumerator.allObjects.compactMap { $0 as? URL }
        var scanned = 0
        for url in urls where !url.hasDirectoryPath {
            let data = try Data(contentsOf: url)
            let text = String(decoding: data, as: UTF8.self).lowercased()
            #expect(!text.contains(Self.phone.lowercased()), "\(url.lastPathComponent)")
            scanned += 1
        }
        #expect(scanned >= 4)
    }
}

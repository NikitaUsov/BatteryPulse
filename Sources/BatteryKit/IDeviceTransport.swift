import BatteryCore
import Dispatch
import Foundation
import Synchronization

/// Reads iPhones and iPads attached to the Mac by USB or Wi-Fi.
///
/// On macOS this is ``MobileDeviceTransport`` (Apple's private MobileDevice framework). A
/// client of usbmuxd and lockdown could replace it if Apple breaks the framework; parsing and
/// reports only see ``IDeviceInfo`` and ``IDeviceCapture``.
public protocol IDeviceTransport: Sendable {
    /// The attached devices.
    ///
    /// - Parameter readingIdentity: connect to each device for its name, model and OS version
    ///   (`bpulse --devices`); a device whose identity isn't read in time is listed by identifier
    ///   alone (see ``IDeviceListBuilder``). Without it no device is connected to and the entries
    ///   carry only the identifier and interfaces (`bpulse --device <n>`).
    /// - Returns: one entry per device even when it is attached by USB and Wi-Fi, in
    ///   ``IDeviceList/sorted(_:)`` order (by identifier, so the same order either way).
    /// - Throws: ``IDeviceError``.
    func devices(readingIdentity: Bool) async throws -> [IDeviceInfo]

    /// Reads the battery of the device with this ``IDeviceInfo/id``. Problems on the device
    /// (not trusted, locked, no answer) are recorded in the capture (``IDeviceCapture/problem``);
    /// only finding the device throws ``IDeviceError``.
    func capture(deviceID: String) async throws -> IDeviceCapture
}

public enum SystemDevices {
    /// The transport for this platform, or `nil` where devices can't be read (Linux, iOS).
    public static func makeTransport() -> (any IDeviceTransport)? {
        #if os(macOS)
        MobileDeviceTransport()
        #else
        nil
        #endif
    }

    /// USB arrivals and terminations of iPhones and iPads (IOKit), or `nil` where there are none
    /// to watch (Linux, iOS).
    public static func makeAttachEvents() -> (any IDeviceAttachEvents)? {
        #if os(macOS)
        USBDeviceWatcher()
        #else
        nil
        #endif
    }
}

public enum IDeviceError: Error, Sendable, Equatable, CustomStringConvertible {
    /// MobileDevice.framework, or a function the read needs, couldn't be loaded.
    case frameworkUnavailable(String)
    /// Watching for devices failed.
    case subscriptionFailed(IDeviceStatus)
    /// The device is no longer attached.
    case deviceNotFound
    /// The framework didn't return in time; the call is abandoned, not cancelled.
    case timedOut(seconds: Int)

    public var description: String {
        switch self {
        case .frameworkUnavailable(let detail):
            "Apple's MobileDevice framework isn't available (\(detail))."
        case .subscriptionFailed(let status):
            "Couldn't watch for connected devices (\(status))."
        case .deviceNotFound:
            "The device is no longer connected."
        case .timedOut(let seconds):
            "The device didn't answer within \(seconds) s."
        }
    }
}

// MARK: - Lockdown calls

/// One connection to a device's lockdown service and the calls a battery read makes on it.
///
/// ``MobileDeviceTransport`` implements it with MobileDevice.framework; a usbmuxd/lockdown
/// client would implement the same calls. A link is used from one thread at a time.
public protocol IDeviceLink: AnyObject {
    var connection: IDeviceConnection { get }
    func connect() -> IDeviceStatus
    /// Whether this Mac holds a pairing record for the device; `nil` when it can't tell.
    func isPaired() -> Bool?
    func validatePairing() -> IDeviceStatus
    func startSession() -> IDeviceStatus
    /// A lockdown value: `key` in `domain` (the global domain when `nil`), or the whole domain
    /// when `key` is `nil`.
    func copyValue(domain: String?, key: String?) -> PropertyValue?
    /// Starts a lockdown service; `send` and `receive` then talk to it.
    func startService(_ name: String) -> IDeviceStatus
    func send(_ message: PropertyDictionary) -> IDeviceStatus
    func receive() -> (status: IDeviceStatus, reply: PropertyDictionary?)
    /// Closes the service connection; safe to call when none is open.
    func closeService()
    func stopSession() -> IDeviceStatus
    func disconnect() -> IDeviceStatus
}

/// The battery read itself, the same for any ``IDeviceLink``.
///
/// Connect, read the identity values (lockdown gives them without a session), validate the
/// pairing and start a session (no pairing of our own: a device that doesn't trust this Mac is
/// reported as such), read the lockdown battery domain, start the diagnostics relay, ask for the
/// battery entry (`AppleSmartBattery`, else `IOPMPowerSource`) and the child entries, say
/// `Goodbye`, then close in reverse order. A failed send or receive ends the conversation: replies
/// carry no request ID, so a late reply could be taken for the next one.
public enum IDeviceReader {
    /// Lockdown values recorded with each capture.
    public static let identityKeys = [
        "DeviceName", "DeviceClass", "ProductType", "ProductVersion", "BuildVersion", "HardwareModel",
    ]

    /// Identity for the device list, over the first link that connects.
    public static func info(id: String, links: [any IDeviceLink]) -> IDeviceInfo {
        var info = IDeviceInfo(id: id, connections: links.map(\.connection))
        for link in links where link.connect().isSuccess {
            info.isPaired = link.isPaired()
            func value(_ key: String) -> String? { link.copyValue(domain: nil, key: key)?.stringValue }
            info.name = value("DeviceName")
            info.deviceClass = value("DeviceClass")
            info.productType = value("ProductType")
            info.productVersion = value("ProductVersion")
            _ = link.disconnect()
            break
        }
        return info
    }

    /// The identities for the device list, one device at a time, recorded in `builder` until it
    /// stops waiting. Devices attached by USB are read first: a device that stops answering is
    /// most likely on Wi-Fi, and the reads queued behind a stuck one never happen.
    ///
    /// - Parameters:
    ///   - groups: the attachments, grouped per device.
    ///   - builder: the list being built.
    ///   - link: the link for one attachment; made only when its device is read.
    public static func readIdentities<Item>(
        of groups: [[IDeviceAttachment<Item>]], into builder: IDeviceListBuilder,
        link: (IDeviceAttachment<Item>) -> any IDeviceLink
    ) {
        guard builder.begin(groups.map { IDeviceAttachment.info(for: $0) }) else { return }
        // The index breaks ties: devices on the same interface keep their arrival order.
        let order = groups.indices.sorted { lhs, rhs in
            let left = (groups[lhs].first?.connection.sortOrder ?? 0, lhs)
            let right = (groups[rhs].first?.connection.sortOrder ?? 0, rhs)
            return left < right
        }
        for index in order {
            let group = groups[index]
            let entry = info(id: group.first?.id ?? "", links: group.map(link))
            guard builder.record(entry, at: index) else { return }
        }
    }

    /// Reads the battery over each link in turn (USB first) until one returns the battery
    /// entry. A device that doesn't trust this Mac, or is locked, isn't tried again over the
    /// next link. Without a battery, the attempt that got furthest is returned.
    public static func capture(id: String, links: [any IDeviceLink]) -> IDeviceCapture {
        var best: IDeviceCapture?
        for link in links {
            var capture = capture(link: link)
            capture.device[IDeviceCapture.Key.identifier] = .string(id)
            if capture.batteryEntry != nil { return capture }
            if best.map({ progress(of: capture) > progress(of: $0) }) ?? true { best = capture }
            switch capture.problem {
            case .notTrusted?, .locked?: return capture
            default: continue
            }
        }
        return best ?? IDeviceCapture(device: [IDeviceCapture.Key.identifier: .string(id)])
    }

    /// How far an attempt got: replies received, then calls that succeeded.
    static func progress(of capture: IDeviceCapture) -> Int {
        capture.exchanges.filter { $0.reply != nil }.count * 100 + capture.steps.filter(\.status.isSuccess).count
    }

    /// One attempt over one link. Every call made is in ``IDeviceCapture/steps``.
    public static func capture(link: any IDeviceLink) -> IDeviceCapture {
        var capture = IDeviceCapture(device: [IDeviceCapture.Key.connection: .string(link.connection.rawValue)])
        let connected = link.connect()
        capture.steps.append(.init(.connect, connected))
        guard connected.isSuccess else { return capture }

        capture.isPaired = link.isPaired()
        for key in identityKeys {
            if let value = link.copyValue(domain: nil, key: key) { capture.device[key] = value }
        }
        readInSession(link, into: &capture)
        capture.steps.append(.init(.disconnect, link.disconnect()))
        return capture
    }

    private static func readInSession(_ link: any IDeviceLink, into capture: inout IDeviceCapture) {
        capture.steps.append(.init(.validatePairing, link.validatePairing()))
        let session = link.startSession()
        capture.steps.append(.init(.startSession, session))
        // "Session active": one is already open on this connection; use it, but don't stop it.
        guard session.isSuccess || session == .sessionActive else { return }

        if let battery = link.copyValue(domain: DiagnosticsRelay.batteryDomain, key: nil)?.dictionaryValue {
            capture.lockdownBattery = battery
        }
        let service = link.startService(DiagnosticsRelay.service)
        capture.steps.append(.init(.startService, service))
        if service.isSuccess {
            queryRelay(link, into: &capture)
            link.closeService()
            capture.steps.append(.init(.closeService, .success))
        }
        if session.isSuccess { capture.steps.append(.init(.stopSession, link.stopSession())) }
    }

    private static func queryRelay(_ link: any IDeviceLink, into capture: inout IDeviceCapture) {
        for className in DiagnosticsRelay.batteryClasses {
            let request = DiagnosticsRelay.registryRequest(entryClass: className)
            guard let reply = exchange(request, over: link, into: &capture) else { return }
            if DiagnosticsRelay.registryEntry(in: reply) != nil { break }
        }
        for className in DiagnosticsRelay.childClasses {
            let request = DiagnosticsRelay.registryRequest(entryClass: className)
            guard exchange(request, over: link, into: &capture) != nil else { return }
        }
        _ = exchange(DiagnosticsRelay.goodbye, over: link, into: &capture)
    }

    /// Sends one request and receives its reply; `nil` (and a recorded failure) if either fails.
    private static func exchange(
        _ request: PropertyDictionary, over link: any IDeviceLink, into capture: inout IDeviceCapture
    ) -> PropertyDictionary? {
        let sent = link.send(request)
        guard sent.isSuccess else {
            capture.exchanges.append(.init(request: request, reply: nil))
            capture.steps.append(.init(.send, sent))
            return nil
        }
        let (received, reply) = link.receive()
        guard received.isSuccess, let reply else {
            capture.exchanges.append(.init(request: request, reply: nil))
            capture.steps.append(.init(.receive, received.isSuccess ? .missingResult : received))
            return nil
        }
        capture.exchanges.append(.init(request: request, reply: reply))
        return reply
    }
}

// MARK: - Attachments

/// One interface a device is attached on, with the transport's handle for it.
public struct IDeviceAttachment<Item> {
    public var id: String
    public var connection: IDeviceConnection
    public var item: Item

    public init(id: String, connection: IDeviceConnection, item: Item) {
        self.id = id
        self.connection = connection
        self.item = item
    }

    /// The list entry for one group from ``grouped(_:)``, made without connecting: identifier
    /// and interfaces only, so it is listed as an unknown device.
    public static func info(for group: [Self]) -> IDeviceInfo {
        IDeviceInfo(id: group.first?.id ?? "", connections: group.map(\.connection))
    }

    /// One group per device in first-seen order, USB first within a group. A device attached by
    /// USB and Wi-Fi is listed twice with the same identifier; a repeated identifier and
    /// connection is dropped. An empty identifier proves nothing, so it gets a group of its own.
    public static func grouped(_ attachments: [Self]) -> [[Self]] {
        var groups: [[Self]] = []
        var groupIndex: [String: Int] = [:]
        for attachment in attachments {
            guard !attachment.id.isEmpty else {
                groups.append([attachment])
                continue
            }
            if let index = groupIndex[attachment.id] {
                guard !groups[index].contains(where: { $0.connection == attachment.connection }) else { continue }
                groups[index].append(attachment)
            } else {
                groupIndex[attachment.id] = groups.count
                groups.append([attachment])
            }
        }
        // `enumerated` keeps the arrival order among equals; `sorted(by:)` alone isn't stable.
        return groups.map { group in
            group.enumerated()
                .sorted { ($0.element.connection.sortOrder, $0.offset) < ($1.element.connection.sortOrder, $1.offset) }
                .map(\.element)
        }
    }
}

extension IDeviceConnection {
    /// USB first: it answers more reliably than Wi-Fi and doesn't keep the device's radio busy.
    var sortOrder: Int {
        switch self {
        case .usb: 0
        case .wifi: 1
        case .unknown: 2
        }
    }
}

// MARK: - Deadlines

/// Runs blocking framework calls off the caller's thread and stops waiting after a deadline.
///
/// The calls themselves can't be cancelled: a call stuck inside the framework keeps `queue`
/// busy, and later work waits behind it. The relay's socket timeouts make that unlikely; the
/// deadline guarantees the caller (`bpulse` or ``IDeviceMonitor``) never waits longer than
/// `timeout`.
public enum BlockingWork {
    public static func run<T: Sendable>(
        on queue: DispatchQueue, timeout: TimeInterval, _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
            let once = ResumeOnce(continuation)
            queue.async { once.resume(with: Result { try work() }) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.resume(with: .failure(IDeviceError.timedOut(seconds: Int(timeout.rounded(.up)))))
            }
        }
    }

    /// Resumes a continuation exactly once, whichever of the work and the deadline comes first.
    private final class ResumeOnce<T: Sendable>: Sendable {
        private let continuation: Mutex<CheckedContinuation<T, any Error>?>

        init(_ continuation: CheckedContinuation<T, any Error>) {
            self.continuation = Mutex(continuation)
        }

        func resume(with result: Result<T, any Error>) {
            // Taken under the lock, resumed outside it.
            continuation.withLock { $0.take() }?.resume(with: result)
        }
    }
}

/// The device list of `devices(readingIdentity: true)` while the transport builds it, and the
/// caller's wait for it.
///
/// The transport discovers the devices, then connects to one device at a time for its identity
/// (``IDeviceReader/readIdentities(of:into:link:)``), all on its one serial queue. Lockdown calls
/// have no timeout of their own and can't be interrupted: a device that stopped answering blocks
/// the queue, and every read behind it waits. So the caller waits for discovery up to the
/// overall deadline, then at most `identityTimeout` for each identity. When a read overruns, or
/// the overall deadline passes, the caller gets the list as it stands: the device being read and
/// those not read yet are listed by identifier alone ("Unknown device"), and the transport skips
/// the remaining reads once its queue frees up. The trade-off: a stuck device costs the devices
/// read after it their names, never the list itself.
public final class IDeviceListBuilder: Sendable {
    private struct State {
        /// `nil` until discovery ends.
        var entries: [IDeviceInfo]?
        /// Counts discovery and each identity read; a deadline that finds it unchanged ends the wait.
        var step = 0
        /// `nil` once the caller has its answer.
        var continuation: CheckedContinuation<[IDeviceInfo], any Error>?
    }

    private let state = Mutex(State())
    private let identityTimeout: TimeInterval

    private init(identityTimeout: TimeInterval) {
        self.identityTimeout = identityTimeout
    }

    /// Runs `work` on `queue` and returns the list it builds with ``begin(_:)`` and
    /// ``record(_:at:)``, sorted (``IDeviceList/sorted(_:)``). Throws what `work` throws, or
    /// ``IDeviceError/timedOut(seconds:)`` when discovery hasn't ended within `timeout`.
    public static func run(
        on queue: DispatchQueue, timeout: TimeInterval, identityTimeout: TimeInterval,
        _ work: @escaping @Sendable (IDeviceListBuilder) throws -> Void
    ) async throws -> [IDeviceInfo] {
        let builder = IDeviceListBuilder(identityTimeout: identityTimeout)
        return try await withCheckedThrowingContinuation { continuation in
            builder.wait(with: continuation)
            queue.async {
                do {
                    try work(builder)
                    builder.workEnded(throwing: nil)
                } catch {
                    builder.workEnded(throwing: error)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                builder.deadlinePassed(timeout: timeout)
            }
        }
    }

    /// Discovery ended with these devices, unnamed. Returns whether to read their identities:
    /// `false` once the caller has stopped waiting.
    public func begin(_ devices: [IDeviceInfo]) -> Bool {
        let step: Int? = state.withLock { state in
            guard state.continuation != nil else { return nil }
            state.entries = devices
            state.step += 1
            return state.step
        }
        return startDeadline(of: step)
    }

    /// The identity read for the device at `index` in ``begin(_:)``'s list. Returns whether to
    /// read the next one: `false` once the caller has stopped waiting.
    public func record(_ info: IDeviceInfo, at index: Int) -> Bool {
        let step: Int? = state.withLock { state in
            guard state.continuation != nil, state.entries?.indices.contains(index) == true else { return nil }
            state.entries?[index] = info
            state.step += 1
            return state.step
        }
        return startDeadline(of: step)
    }

    private func wait(with continuation: CheckedContinuation<[IDeviceInfo], any Error>) {
        state.withLock { $0.continuation = continuation }
    }

    /// Starts the deadline of the read that `step` begins; `false`, and none, when the caller
    /// has stopped waiting.
    private func startDeadline(of step: Int?) -> Bool {
        guard let step else { return false }
        DispatchQueue.global().asyncAfter(deadline: .now() + identityTimeout) {
            self.identityOverran(step: step)
        }
        return true
    }

    private func workEnded(throwing error: (any Error)?) {
        guard let taken = take() else { return }
        if let error {
            taken.continuation.resume(throwing: error)
        } else {
            taken.continuation.resume(returning: IDeviceList.sorted(taken.entries ?? []))
        }
    }

    private func deadlinePassed(timeout: TimeInterval) {
        guard let taken = take() else { return }
        if let entries = taken.entries {
            taken.continuation.resume(returning: IDeviceList.sorted(entries))
        } else {
            taken.continuation.resume(throwing: IDeviceError.timedOut(seconds: Int(timeout.rounded(.up))))
        }
    }

    private func identityOverran(step: Int) {
        guard let taken = take(ifStillAt: step) else { return }
        taken.continuation.resume(returning: IDeviceList.sorted(taken.entries ?? []))
    }

    /// Takes the caller's continuation, so it is resumed once (outside the lock); with `step`,
    /// only while no read has ended since that step.
    private func take(ifStillAt step: Int? = nil) -> (
        continuation: CheckedContinuation<[IDeviceInfo], any Error>, entries: [IDeviceInfo]?
    )? {
        state.withLock { state in
            guard let pending = state.continuation, step == nil || step == state.step else { return nil }
            state.continuation = nil
            return (pending, state.entries)
        }
    }
}

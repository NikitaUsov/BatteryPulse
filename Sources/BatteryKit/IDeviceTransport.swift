import BatteryCore
import Dispatch
import Foundation

/// Reads iPhones and iPads attached to the Mac by USB or Wi-Fi.
///
/// On macOS this is ``MobileDeviceTransport`` (Apple's private MobileDevice framework). A
/// client of usbmuxd and lockdown could replace it if Apple breaks the framework; parsing and
/// reports only see ``IDeviceInfo`` and ``IDeviceCapture``.
public protocol IDeviceTransport: Sendable {
    /// The attached devices, one entry per device even when it is attached by USB and Wi-Fi, in
    /// ``IDeviceList/sorted(_:)`` order. Throws ``IDeviceError``.
    func devices() async throws -> [IDeviceInfo]

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
/// deadline guarantees the caller (the CLI) never hangs.
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
    private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, any Error>?

        init(_ continuation: CheckedContinuation<T, any Error>) {
            self.continuation = continuation
        }

        func resume(with result: Result<T, any Error>) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(with: result)
        }
    }
}

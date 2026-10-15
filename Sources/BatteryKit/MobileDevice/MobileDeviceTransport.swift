#if os(macOS)
import BatteryCore
import CoreFoundation
import Foundation

/// ``IDeviceTransport`` over Apple's private MobileDevice framework.
///
/// Each operation runs start to finish on one serial queue, shared by every instance: subscribe to device notifications,
/// wait briefly for the attached devices (already-attached ones are announced right after
/// subscribing), read, unsubscribe. The relay's socket gets send and receive timeouts, and the
/// caller stops waiting after ``listTimeout`` / ``captureTimeout`` whatever the framework does;
/// in the list, after ``identityTimeout`` for one device's identity (``IDeviceListBuilder``).
///
/// Trust comes from Finder: this transport never pairs. A device that doesn't trust this Mac is
/// reported (``IDeviceProblem/notTrusted(_:)``) so the person can tap Trust on it.
public final class MobileDeviceTransport: IDeviceTransport {
    /// The longest wait for attach notifications.
    static let discoveryWindow: TimeInterval = 3
    /// Discovery ends early once the device list hasn't changed for this long.
    static let settleTime: TimeInterval = 1
    /// Send and receive timeout on the relay's socket, in seconds.
    static let socketTimeoutSeconds = 5
    public static let listTimeout: TimeInterval = 30
    /// The longest wait for one device's identity in the list; a connect and a few lockdown
    /// values take well under a second by cable.
    public static let identityTimeout: TimeInterval = 10
    public static let captureTimeout: TimeInterval = 60

    /// One queue for the whole process: the framework's thread safety is undocumented, and the
    /// notification sink is shared.
    private static let queue = DispatchQueue(label: "BatteryPulse.MobileDevice")

    public init() {}

    public func devices(readingIdentity: Bool) async throws -> [IDeviceInfo] {
        guard readingIdentity else {
            // Identifiers and interfaces come with the attach notifications: nothing connects.
            return try await BlockingWork.run(on: Self.queue, timeout: Self.listTimeout) { () throws -> [IDeviceInfo] in
                let library = try MobileDeviceLibrary.shared.get()
                return try MobileDeviceDiscovery.withAttachedDevices(library: library, waitingFor: nil) { groups in
                    IDeviceList.sorted(groups.map { IDeviceAttachment.info(for: $0) })
                }
            }
        }
        return try await IDeviceListBuilder.run(
            on: Self.queue, timeout: Self.listTimeout, identityTimeout: Self.identityTimeout
        ) { builder in
            let library = try MobileDeviceLibrary.shared.get()
            try MobileDeviceDiscovery.withAttachedDevices(library: library, waitingFor: nil) { groups in
                IDeviceReader.readIdentities(of: groups, into: builder) {
                    MobileDeviceLink(library: library, attachment: $0)
                }
            }
        }
    }

    public func capture(deviceID: String) async throws -> IDeviceCapture {
        try await BlockingWork.run(on: Self.queue, timeout: Self.captureTimeout) { () throws -> IDeviceCapture in
            let library = try MobileDeviceLibrary.shared.get()
            return try MobileDeviceDiscovery.withAttachedDevices(library: library, waitingFor: deviceID) {
                groups throws -> IDeviceCapture in
                guard let group = groups.first(where: { $0.first?.id == deviceID }) else {
                    throw IDeviceError.deviceNotFound
                }
                return IDeviceReader.capture(
                    id: deviceID, links: group.map { MobileDeviceLink(library: library, attachment: $0) })
            }
        }
    }
}

// MARK: - Discovery

/// Collects attach (message 1) and detach (2) notifications. Message 3 follows our own
/// unsubscribe and is ignored, never answered with a new subscription; other messages are
/// ignored too.
///
/// One instance lives for the whole process and the subscription's context is unused, so a
/// message arriving late, on whichever thread the framework picks, never meets freed memory.
final class MobileDeviceSink: @unchecked Sendable {
    // `@unchecked`: every stored property is guarded by `lock`.
    static let shared = MobileDeviceSink()

    private let lock = NSLock()
    private var devices: [AnyObject] = []
    private var isActive = false

    func begin() {
        lock.lock()
        defer { lock.unlock() }
        devices = []
        isActive = true
    }

    func end() {
        lock.lock()
        defer { lock.unlock() }
        devices = []
        isActive = false
    }

    /// The attached devices, each retained for as long as the caller holds it.
    func snapshot() -> [AnyObject] {
        lock.lock()
        defer { lock.unlock() }
        return devices
    }

    func receive(device: UnsafeMutableRawPointer?, message: UInt32) {
        guard message == 1 || message == 2, let device else { return }
        lock.lock()
        defer { lock.unlock() }
        guard isActive else { return }
        // Borrowed from the framework; storing the reference retains the AMDevice.
        let object = Unmanaged<AnyObject>.fromOpaque(device).takeUnretainedValue()
        if message == 1 {
            if !devices.contains(where: { $0 === object }) { devices.append(object) }
        } else {
            devices.removeAll { $0 === object }
        }
    }
}

enum MobileDeviceDiscovery {
    /// Subscribes, waits for the attached devices, runs `body` with them grouped per device
    /// (USB first) while still subscribed, then unsubscribes.
    ///
    /// - Parameter wanted: a UDID to stop waiting for as soon as it appears.
    static func withAttachedDevices<T>(
        library: MobileDeviceLibrary, waitingFor wanted: String?,
        _ body: ([[IDeviceAttachment<AnyObject>]]) throws -> T
    ) throws -> T {
        let sink = MobileDeviceSink.shared
        sink.begin()
        defer { sink.end() }

        let subscription = try subscribe(library: library)
        defer { _ = library.notificationUnsubscribe(subscription) }

        waitForDevices(library: library, sink: sink, wanted: wanted)
        var objects = sink.snapshot()
        for listed in listedDevices(library: library) where !objects.contains(where: { $0 === listed }) {
            objects.append(listed)
        }
        let attachments = objects.compactMap { attachment(for: $0, library: library) }
        return try body(IDeviceAttachment.grouped(attachments))
    }

    /// `AMDeviceNotificationSubscribe`, delivering to ``MobileDeviceSink/shared``.
    ///
    /// The callback may run on this thread's run loop (pumped by `waitForDevices`), on the main
    /// run loop or on a thread of the framework's; the sink is safe on any of them. Non-generic,
    /// so the closure, which captures nothing, converts to a C function pointer.
    private static func subscribe(library: MobileDeviceLibrary) throws -> UnsafeMutableRawPointer {
        var subscription: UnsafeMutableRawPointer?
        let code = library.notificationSubscribe(
            { info, _ in
                guard let info else { return }
                let device = info.load(as: UnsafeMutableRawPointer?.self)
                let message = info.load(fromByteOffset: MemoryLayout<UnsafeMutableRawPointer>.size, as: UInt32.self)
                MobileDeviceSink.shared.receive(device: device, message: message)
            }, 0, 0, nil, &subscription)
        let status = IDeviceStatus(code: code)
        guard status.isSuccess, let subscription else {
            throw IDeviceError.subscriptionFailed(status.isSuccess ? .missingResult : status)
        }
        return subscription
    }

    /// Runs this thread's run loop in short slices until the device list settles, `wanted`
    /// appears or ``MobileDeviceTransport/discoveryWindow`` passes.
    private static func waitForDevices(library: MobileDeviceLibrary, sink: MobileDeviceSink, wanted: String?) {
        let start = Date()
        var count = 0
        var lastChange = start
        while true {
            let result = CFRunLoopRunInMode(.defaultMode, 0.1, false)
            // No sources on this thread's run loop: the framework delivers elsewhere. Don't spin.
            if result == .finished { Thread.sleep(forTimeInterval: 0.1) }

            let now = Date()
            let devices = sink.snapshot()
            if devices.count != count {
                count = devices.count
                lastChange = now
            }
            if now.timeIntervalSince(start) >= MobileDeviceTransport.discoveryWindow { return }
            let quiet = now.timeIntervalSince(lastChange)
            if let wanted {
                // A short grace collects the device's second interface (USB and Wi-Fi).
                if quiet >= 0.5, devices.contains(where: { identifier(of: $0, library: library) == wanted }) { return }
            } else if count > 0, quiet >= MobileDeviceTransport.settleTime {
                return
            }
        }
    }

    /// `AMDCreateDeviceList`, a second opinion: it can miss a Wi-Fi device that notifications
    /// report, but costs nothing to ask.
    private static func listedDevices(library: MobileDeviceLibrary) -> [AnyObject] {
        guard let create = library.createDeviceList, let list = create()?.takeRetainedValue() else { return [] }
        return (0..<CFArrayGetCount(list)).compactMap { index in
            CFArrayGetValueAtIndex(list, index).map { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() }
        }
    }

    private static func identifier(of device: AnyObject, library: MobileDeviceLibrary) -> String {
        let pointer = Unmanaged.passUnretained(device).toOpaque()
        return library.copyDeviceIdentifier(pointer).map { $0.takeRetainedValue() as String } ?? ""
    }

    /// The device's UDID and interface; `nil` for a companion proxy (a Watch through its iPhone).
    private static func attachment(for device: AnyObject, library: MobileDeviceLibrary)
        -> IDeviceAttachment<AnyObject>?
    {
        let interfaceType = Int(library.getInterfaceType(Unmanaged.passUnretained(device).toOpaque()))
        guard interfaceType != IDeviceConnection.companionProxyInterfaceType else { return nil }
        return IDeviceAttachment(
            id: identifier(of: device, library: library), connection: IDeviceConnection(interfaceType: interfaceType),
            item: device)
    }
}

// MARK: - Calls

/// ``IDeviceLink`` for one `AMDeviceRef`, which it keeps retained.
final class MobileDeviceLink: IDeviceLink {
    let connection: IDeviceConnection
    private let library: MobileDeviceLibrary
    private let device: AnyObject
    /// The `AMDServiceConnectionRef` from ``startService(_:)`` (+1), released by
    /// ``closeService()``.
    private var service: UnsafeMutableRawPointer?

    init(library: MobileDeviceLibrary, attachment: IDeviceAttachment<AnyObject>) {
        self.library = library
        self.device = attachment.item
        self.connection = attachment.connection
    }

    deinit {
        closeService()
    }

    private var pointer: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(device).toOpaque()
    }

    func connect() -> IDeviceStatus {
        IDeviceStatus(code: library.connect(pointer))
    }

    func isPaired() -> Bool? {
        library.isPaired.map { $0(pointer) != 0 }
    }

    func validatePairing() -> IDeviceStatus {
        IDeviceStatus(code: library.validatePairing(pointer))
    }

    func startSession() -> IDeviceStatus {
        IDeviceStatus(code: library.startSession(pointer))
    }

    func copyValue(domain: String?, key: String?) -> PropertyValue? {
        let value = library.copyValue(pointer, domain.map { $0 as CFString }, key.map { $0 as CFString })
        return value.flatMap { PropertyValue(any: $0.takeRetainedValue()) }
    }

    func startService(_ name: String) -> IDeviceStatus {
        var connection: UnsafeMutableRawPointer?
        let status = IDeviceStatus(code: library.secureStartService(pointer, name as CFString, nil, &connection))
        guard status.isSuccess else { return status }
        guard let connection else { return .missingResult }
        service = connection
        setTimeouts(socket: library.getSocket(connection))
        return .success
    }

    /// Bounds every send and receive: without it, a device that vanishes mid-read blocks the
    /// receive forever. The TLS layer reads from this socket.
    private func setTimeouts(socket: Int32) {
        guard socket >= 0 else { return }
        var timeout = timeval(tv_sec: MobileDeviceTransport.socketTimeoutSeconds, tv_usec: 0)
        let size = socklen_t(MemoryLayout<timeval>.size)
        _ = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, size)
        _ = setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, size)
    }

    func send(_ message: PropertyDictionary) -> IDeviceStatus {
        guard let service else { return .notConnected }
        guard let dictionary = PropertyValue.dictionary(message).foundationValue as? [String: Any] else {
            return .missingResult
        }
        return IDeviceStatus(code: library.sendMessage(service, dictionary as CFDictionary, .xmlFormat_v1_0))
    }

    func receive() -> (status: IDeviceStatus, reply: PropertyDictionary?) {
        guard let service else { return (.notConnected, nil) }
        var reply: Unmanaged<CFTypeRef>?
        var format = CFPropertyListFormat.xmlFormat_v1_0
        let status = IDeviceStatus(code: library.receiveMessage(service, &reply, &format))
        // Taken even on failure, so a partial reply isn't leaked.
        let object = reply?.takeRetainedValue()
        guard status.isSuccess else { return (status, nil) }
        guard let object, let dictionary = PropertyValue.dictionary(fromAny: object) else {
            return (.missingResult, nil)
        }
        return (.success, dictionary)
    }

    func closeService() {
        guard let service else { return }
        library.invalidate(service)
        Unmanaged<AnyObject>.fromOpaque(service).release()
        self.service = nil
    }

    func stopSession() -> IDeviceStatus {
        IDeviceStatus(code: library.stopSession(pointer))
    }

    func disconnect() -> IDeviceStatus {
        IDeviceStatus(code: library.disconnect(pointer))
    }
}
#endif

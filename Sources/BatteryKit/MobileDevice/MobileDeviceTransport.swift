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
    static let discoveryWindow: Duration = .seconds(3)
    /// Discovery ends early once the device list hasn't changed for this long.
    static let settleTime: Duration = .seconds(1)
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
        // Unsafe: the AMDeviceRef's address, which the framework keeps valid during the callback.
        guard message == 1 || message == 2, let device = unsafe device else { return }
        lock.lock()
        defer { lock.unlock() }
        guard isActive else { return }
        // Borrowed from the framework; storing the reference retains the AMDevice.
        let object = unsafe Unmanaged<AnyObject>.fromOpaque(device).takeUnretainedValue()
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
    /// - Parameters:
    ///   - library: the loaded MobileDevice framework.
    ///   - wanted: a UDID to stop waiting for as soon as it appears.
    ///   - body: the work to do with the attached devices.
    /// - Returns: what `body` returns.
    /// - Throws: ``IDeviceError/subscriptionFailed(_:)``, or what `body` throws.
    static func withAttachedDevices<T>(
        library: MobileDeviceLibrary, waitingFor wanted: String?,
        _ body: ([[IDeviceAttachment<AnyObject>]]) throws -> T
    ) throws -> T {
        let sink = MobileDeviceSink.shared
        sink.begin()
        defer { sink.end() }

        // Unsafe: the subscription is the framework's opaque pointer, ended once, here.
        let subscription = try unsafe subscribe(library: library)
        defer { _ = unsafe library.notificationUnsubscribe(subscription) }

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
        // Unsafe: a call through the looked-up address, with a C callback and the subscription
        // through an out-pointer.
        let code = unsafe library.notificationSubscribe(
            { info, _ in
                // Unsafe: the callback's info is the framework's struct, read at the offsets its
                // header gives (device at 0, message at 8), during the callback only.
                guard let info = unsafe info else { return }
                let device = unsafe info.load(as: UnsafeMutableRawPointer?.self)
                let message = unsafe info.load(
                    fromByteOffset: MemoryLayout<UnsafeMutableRawPointer>.size, as: UInt32.self)
                unsafe MobileDeviceSink.shared.receive(device: device, message: message)
            }, 0, 0, nil, &subscription)
        let status = IDeviceStatus(code: code)
        guard status.isSuccess, let subscription = unsafe subscription else {
            throw IDeviceError.subscriptionFailed(status.isSuccess ? .missingResult : status)
        }
        return unsafe subscription
    }

    /// Runs this thread's run loop in short slices until the device list settles, `wanted`
    /// appears or ``MobileDeviceTransport/discoveryWindow`` passes.
    ///
    /// Elapsed time is monotonic: a wall clock set back mid-wait would otherwise hold the
    /// transport's queue, and every call behind it, for as long as the clock moved.
    private static func waitForDevices(library: MobileDeviceLibrary, sink: MobileDeviceSink, wanted: String?) {
        let clock = ContinuousClock()
        let start = clock.now
        var count = 0
        var lastChange = start
        while true {
            let result = CFRunLoopRunInMode(.defaultMode, 0.1, false)
            // No sources on this thread's run loop: the framework delivers elsewhere. Don't spin.
            if result == .finished { Thread.sleep(forTimeInterval: 0.1) }

            let now = clock.now
            let devices = sink.snapshot()
            if devices.count != count {
                count = devices.count
                lastChange = now
            }
            if start.duration(to: now) >= MobileDeviceTransport.discoveryWindow { return }
            let quiet = lastChange.duration(to: now)
            if let wanted {
                // A short grace collects the device's second interface (USB and Wi-Fi).
                if quiet >= .milliseconds(500),
                    devices.contains(where: { identifier(of: $0, library: library) == wanted })
                {
                    return
                }
            } else if count > 0, quiet >= MobileDeviceTransport.settleTime {
                return
            }
        }
    }

    /// `AMDCreateDeviceList`, a second opinion: it can miss a Wi-Fi device that notifications
    /// report, but costs nothing to ask.
    private static func listedDevices(library: MobileDeviceLibrary) -> [AnyObject] {
        // Unsafe: a call through the looked-up address; the list is retained once for us (Copy)
        // and taken once, and its devices belong to it (Get), so they are borrowed, then retained by
        // the returned array.
        guard let create = unsafe library.createDeviceList, let list = unsafe create()?.takeRetainedValue() else {
            return []
        }
        return (0..<CFArrayGetCount(list)).compactMap { index in
            unsafe CFArrayGetValueAtIndex(list, index).map {
                unsafe Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue()
            }
        }
    }

    private static func identifier(of device: AnyObject, library: MobileDeviceLibrary) -> String {
        // Unsafe: the device's address, valid while `device` retains it, and a call through the
        // looked-up address whose string is retained once for us (Copy) and taken once.
        let pointer = unsafe Unmanaged.passUnretained(device).toOpaque()
        return unsafe library.copyDeviceIdentifier(pointer).map { unsafe $0.takeRetainedValue() as String } ?? ""
    }

    /// The device's UDID and interface; `nil` for a companion proxy (a Watch through its iPhone).
    private static func attachment(for device: AnyObject, library: MobileDeviceLibrary)
        -> IDeviceAttachment<AnyObject>?
    {
        // Unsafe: the device's address, valid while `device` retains it.
        let interfaceType = unsafe Int(library.getInterfaceType(Unmanaged.passUnretained(device).toOpaque()))
        guard interfaceType != IDeviceConnection.companionProxyInterfaceType else { return nil }
        return IDeviceAttachment(
            id: identifier(of: device, library: library), connection: IDeviceConnection(interfaceType: interfaceType),
            item: device)
    }
}

// MARK: - Calls

/// ``IDeviceLink`` for one `AMDeviceRef`, which it keeps retained.
///
/// `@safe`: the service connection it keeps is started in ``startService(_:)``, used only by its
/// own calls, and invalidated and released once, in ``closeService()``.
@safe
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

    /// The AMDeviceRef's address, valid while `device` retains it. Unsafe, in every call below that
    /// passes it: a call through a looked-up address, with this address.
    private var pointer: UnsafeMutableRawPointer {
        unsafe Unmanaged.passUnretained(device).toOpaque()
    }

    func connect() -> IDeviceStatus {
        unsafe IDeviceStatus(code: library.connect(pointer))
    }

    func isPaired() -> Bool? {
        unsafe library.isPaired.map { unsafe $0(pointer) != 0 }
    }

    func validatePairing() -> IDeviceStatus {
        unsafe IDeviceStatus(code: library.validatePairing(pointer))
    }

    func startSession() -> IDeviceStatus {
        unsafe IDeviceStatus(code: library.startSession(pointer))
    }

    func copyValue(domain: String?, key: String?) -> PropertyValue? {
        let value = unsafe library.copyValue(pointer, domain.map { $0 as CFString }, key.map { $0 as CFString })
        // Unsafe: the value is retained once for us (Copy) and taken once.
        return unsafe value.flatMap { unsafe PropertyValue(any: $0.takeRetainedValue()) }
    }

    func startService(_ name: String) -> IDeviceStatus {
        // Unsafe: the connection comes back through an out-pointer, +1, and is kept in `service`
        // until ``closeService()`` releases it.
        var connection: UnsafeMutableRawPointer?
        let status = unsafe IDeviceStatus(
            code: library.secureStartService(pointer, name as CFString, nil, &connection))
        guard status.isSuccess else { return status }
        guard let connection = unsafe connection else { return .missingResult }
        unsafe service = connection
        // Unsafe: a call through a looked-up address, with the connection just stored.
        unsafe setTimeouts(socket: library.getSocket(connection))
        return .success
    }

    /// Bounds every send and receive: without it, a device that vanishes mid-read blocks the
    /// receive forever. The TLS layer reads from this socket.
    private func setTimeouts(socket: Int32) {
        guard socket >= 0 else { return }
        var timeout = timeval(tv_sec: MobileDeviceTransport.socketTimeoutSeconds, tv_usec: 0)
        let size = socklen_t(MemoryLayout<timeval>.size)
        // Unsafe: the option's value through a pointer to `timeout`, `size` bytes long.
        _ = unsafe setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, size)
        _ = unsafe setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, size)
    }

    func send(_ message: PropertyDictionary) -> IDeviceStatus {
        // Unsafe: the open connection, and a call through a looked-up address.
        guard let service = unsafe service else { return .notConnected }
        guard let dictionary = PropertyValue.dictionary(message).foundationValue as? [String: Any] else {
            return .missingResult
        }
        return unsafe IDeviceStatus(code: library.sendMessage(service, dictionary as CFDictionary, .xmlFormat_v1_0))
    }

    func receive() -> (status: IDeviceStatus, reply: PropertyDictionary?) {
        // Unsafe: the open connection, a call through a looked-up address, and the reply through an
        // out-pointer, retained once for us and taken once.
        guard let service = unsafe service else { return (.notConnected, nil) }
        var reply: Unmanaged<CFTypeRef>?
        var format = CFPropertyListFormat.xmlFormat_v1_0
        let status = unsafe IDeviceStatus(code: library.receiveMessage(service, &reply, &format))
        // Taken even on failure, so a partial reply isn't leaked.
        let object = unsafe reply?.takeRetainedValue()
        guard status.isSuccess else { return (status, nil) }
        guard let object, let dictionary = PropertyValue.dictionary(fromAny: object) else {
            return (.missingResult, nil)
        }
        return (.success, dictionary)
    }

    func closeService() {
        // Unsafe: the connection is invalidated, released (the one reference `startService(_:)`
        // took) and forgotten, once.
        guard let service = unsafe service else { return }
        unsafe library.invalidate(service)
        unsafe Unmanaged<AnyObject>.fromOpaque(service).release()
        unsafe self.service = nil
    }

    func stopSession() -> IDeviceStatus {
        unsafe IDeviceStatus(code: library.stopSession(pointer))
    }

    func disconnect() -> IDeviceStatus {
        unsafe IDeviceStatus(code: library.disconnect(pointer))
    }
}
#endif

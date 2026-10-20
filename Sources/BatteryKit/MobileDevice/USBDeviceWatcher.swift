#if os(macOS)
import BatteryCore
import Foundation
import IOKit

/// USB arrivals and terminations of iPhones and iPads, from IOKit matching notifications: the
/// trigger for listing devices.
///
/// It touches no device and loads no private framework, so it costs one idle notification port
/// while nothing is plugged in. Apple mobile devices are `IOUSBHostDevice`s with vendor 0x05AC and
/// a product ID in ``mobileProductIDs``; other Apple USB devices (keyboards, adapters) are
/// ignored. All IOKit state lives on one private serial queue.
final class USBDeviceWatcher: IDeviceAttachEvents, Sendable {
    /// Each stream's state is a `Watch`, touched only on this queue.
    private let queue = DispatchQueue(label: "io.github.nikitausov.BatteryPulse.usb-devices")

    static let appleVendorID = 0x05AC
    /// The product IDs iPhones and iPads report over USB.
    static let mobileProductIDs = 0x1290...0x12FF

    func changes() -> AsyncStream<IDeviceAttachChange> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: IDeviceAttachChange.self, bufferingPolicy: .bufferingNewest(1))
        let watch = Watch(continuation: continuation)
        let queue = queue
        // The stream keeps `watch` alive through this closure until the consumer stops.
        continuation.onTermination = { _ in
            queue.async { watch.stop() }
        }
        queue.async { watch.start(on: queue) }
        return stream
    }

    /// A matching dictionary for Apple USB devices. Each notification needs its own: the call
    /// consumes one reference.
    static func matching() -> CFMutableDictionary? {
        guard let matching = IOServiceMatching("IOUSBHostDevice") else { return nil }
        // The same object, toll-free bridged: the key goes into the dictionary IOKit receives.
        (matching as NSMutableDictionary)["idVendor"] = NSNumber(value: appleVendorID)
        return matching
    }

    /// Whether the service is an iPhone or iPad, by its USB product ID.
    static func isMobileDevice(_ service: io_object_t) -> Bool {
        guard
            let value = IORegistryEntryCreateCFProperty(service, "idProduct" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue(),
            let product = (value as? NSNumber)?.intValue
        else { return false }
        return mobileProductIDs.contains(product)
    }

    /// Releases every service in `iterator`, which re-arms its notification, and returns whether
    /// one of them is an iPhone or iPad.
    static func drain(_ iterator: io_iterator_t) -> Bool {
        var found = false
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if isMobileDevice(service) { found = true }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return found
    }
}

/// The IOKit state of one `changes()` stream. Used only on the watcher's queue; IOKit calls the
/// callbacks there too (`IONotificationPortSetDispatchQueue`).
private final class Watch: @unchecked Sendable {
    // `@unchecked`: the `var`s are touched only on the watcher's serial queue, where IOKit calls
    // back too; the class is Sendable only so the stream's handlers can hand it to that queue.
    let continuation: AsyncStream<IDeviceAttachChange>.Continuation
    private var port: IONotificationPortRef?
    private var arrivals: io_iterator_t = 0
    private var terminations: io_iterator_t = 0
    private var isStopped = false

    init(continuation: AsyncStream<IDeviceAttachChange>.Continuation) {
        self.continuation = continuation
    }

    func start(on queue: DispatchQueue) {
        guard !isStopped, port == nil else { return }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            continuation.finish()
            return
        }
        IONotificationPortSetDispatchQueue(port, queue)
        self.port = port
        // Unretained: the stream's termination handler keeps this object alive until `stop()`,
        // which destroys the port first, so no callback runs after that.
        let refCon = Unmanaged.passUnretained(self).toOpaque()
        let arrived = IOServiceAddMatchingNotification(
            port, kIOFirstMatchNotification, USBDeviceWatcher.matching(),
            { refCon, iterator in
                guard let refCon else { return }
                Unmanaged<Watch>.fromOpaque(refCon).takeUnretainedValue().handle(iterator, .arrived)
            }, refCon, &arrivals)
        let terminated = IOServiceAddMatchingNotification(
            port, kIOTerminatedNotification, USBDeviceWatcher.matching(),
            { refCon, iterator in
                guard let refCon else { return }
                Unmanaged<Watch>.fromOpaque(refCon).takeUnretainedValue().handle(iterator, .terminated)
            }, refCon, &terminations)
        guard arrived == KERN_SUCCESS, terminated == KERN_SUCCESS else {
            stop()
            continuation.finish()
            return
        }
        // Draining arms both notifications. The first-match iterator holds the devices already
        // plugged in: one event for them is the initial scan. The terminated one starts empty.
        if USBDeviceWatcher.drain(arrivals) { continuation.yield(.arrived) }
        _ = USBDeviceWatcher.drain(terminations)
    }

    func handle(_ iterator: io_iterator_t, _ change: IDeviceAttachChange) {
        guard !isStopped else { return }
        if USBDeviceWatcher.drain(iterator) { continuation.yield(change) }
    }

    func stop() {
        isStopped = true
        if arrivals != 0 { IOObjectRelease(arrivals) }
        if terminations != 0 { IOObjectRelease(terminations) }
        arrivals = 0
        terminations = 0
        if let port { IONotificationPortDestroy(port) }
        port = nil
    }
}
#endif

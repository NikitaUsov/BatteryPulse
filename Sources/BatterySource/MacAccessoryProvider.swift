#if os(macOS)
import BatteryCore
import Foundation
import os

/// Batteries of connected accessories (Bluetooth keyboards, mice, trackpads, headphones) as the
/// power management daemon publishes them: the data `pmset -g accps` shows. Needs no Bluetooth
/// permission and no entitlement.
///
/// The list comes from `IOPSCopyPowerSourcesByType`, a private IOKit function, and is read with
/// the public `IOPSCopyPowerSourcesList` and `IOPSGetPowerSourceDescription`. The function is
/// looked up rather than declared, so a macOS without it shows accessories as unavailable
/// instead of failing to launch. Changes arrive as notify(3) posts; there is no polling.
///
/// `@safe`: the function address it keeps is called only in ``read()``, which takes the one
/// reference the function returns and hands out Swift values.
@MainActor
@safe
public final class MacAccessoryProvider: AccessoryProvider {
    typealias CopyPowerSourcesByType = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?

    /// `kIOPSSourceForAccessories` (IOPowerSourcesPrivate.h).
    static let accessorySources: Int32 = 4
    /// `kIOPSAccNotifyAttach`, `kIOPSAccNotifyTimeRemaining`, `kIOPSAccNotifyPowerSource`: an
    /// accessory came or went, its charge changed, its power source or charging state changed.
    static let notifications = [
        "com.apple.system.accpowersources.attach",
        "com.apple.system.accpowersources.timeremaining",
        "com.apple.system.accpowersources.source",
    ]
    /// IOKit is linked already (for the public power source functions). `RTLD_NOLOAD` makes sure
    /// the handle is only borrowed from the loaded image, `RTLD_FIRST` that the lookup searches
    /// IOKit alone.
    static let ioKitPath = "/System/Library/Frameworks/IOKit.framework/IOKit"

    private let copyPowerSourcesByType: CopyPowerSourcesByType?

    public init() {
        // Unsafe: the path and the name as C strings, the handle and the address as raw pointers,
        // and a cast that trusts the declared signature (IOPowerSourcesPrivate.h).
        unsafe copyPowerSourcesByType = dlopen(Self.ioKitPath, RTLD_NOW | RTLD_NOLOAD | RTLD_FIRST)
            .flatMap { unsafe dlsym($0, "IOPSCopyPowerSourcesByType") }
            .map { unsafe unsafeBitCast($0, to: CopyPowerSourcesByType.self) }
        // Unsafe: the address is only compared.
        if unsafe copyPowerSourcesByType == nil {
            // dlerror's text names paths, so it stays private. Unsafe: the text is a C string,
            // copied before the next dl call can replace it.
            let reason = unsafe dlerror().map { unsafe String(cString: $0) } ?? "no error text"
            Diagnostics.accessory.error(
                "IOPSCopyPowerSourcesByType isn't available, so accessories are shown as unavailable: \(reason)")
        }
    }

    public func read() -> AccessoryReading? {
        // Unsafe: the call goes through the looked-up address; its result is retained once for us
        // (Copy) and taken once.
        guard let copy = unsafe copyPowerSourcesByType else { return nil }
        guard let blob = unsafe copy(Self.accessorySources)?.takeRetainedValue() else {
            return AccessoryReading(sources: [])
        }
        guard CFGetTypeID(blob) == CFArrayGetTypeID() else {
            Diagnostics.accessory.error(
                "IOPSCopyPowerSourcesByType returned CF type \(CFGetTypeID(blob)), not a list; no accessories shown")
            return AccessoryReading(sources: [])
        }
        return AccessoryReading(
            sources: powerSourceDescriptions(in: blob).compactMap { PropertyValue.dictionary(fromAny: $0) })
    }

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        BatteryObservation(onCancel: observeNotifyKeys(Self.notifications, handler: handler))
    }
}
#endif

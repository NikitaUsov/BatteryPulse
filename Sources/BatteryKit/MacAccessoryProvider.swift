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
@MainActor
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
        copyPowerSourcesByType = dlopen(Self.ioKitPath, RTLD_NOW | RTLD_NOLOAD | RTLD_FIRST)
            .flatMap { dlsym($0, "IOPSCopyPowerSourcesByType") }
            .map { unsafeBitCast($0, to: CopyPowerSourcesByType.self) }
        if copyPowerSourcesByType == nil {
            // dlerror's text names paths, so it stays private.
            let reason = dlerror().map { String(cString: $0) } ?? "no error text"
            Diagnostics.accessory.error(
                "IOPSCopyPowerSourcesByType isn't available, so accessories are shown as unavailable: \(reason)")
        }
    }

    public func read() -> AccessoryReading? {
        guard let copy = copyPowerSourcesByType else { return nil }
        guard let blob = copy(Self.accessorySources)?.takeRetainedValue() else { return AccessoryReading(sources: []) }
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

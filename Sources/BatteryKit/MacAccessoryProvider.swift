#if os(macOS)
import BatteryCore
import Foundation
import IOKit.ps
import notify

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
    /// IOKit is linked already (for the public power source functions), so this only returns a
    /// handle to the loaded image.
    static let ioKitPath = "/System/Library/Frameworks/IOKit.framework/IOKit"

    private let copyPowerSourcesByType: CopyPowerSourcesByType?

    public init() {
        copyPowerSourcesByType = dlopen(Self.ioKitPath, RTLD_NOW)
            .flatMap { dlsym($0, "IOPSCopyPowerSourcesByType") }
            .map { unsafeBitCast($0, to: CopyPowerSourcesByType.self) }
    }

    public func read() -> AccessoryReading? {
        guard let copy = copyPowerSourcesByType else { return nil }
        guard let blob = copy(Self.accessorySources)?.takeRetainedValue(), CFGetTypeID(blob) == CFArrayGetTypeID()
        else { return AccessoryReading(sources: []) }
        // The same calls as MacBatteryProvider.internalBatteryDescription.
        let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] ?? []
        let sources = list.compactMap { source -> PropertyDictionary? in
            let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
            return PropertyValue.dictionary(fromAny: description)
        }
        return AccessoryReading(sources: sources)
    }

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        // notify(3), as in MacBatteryProvider: notify_cancel tears down deterministically.
        var tokens: [Int32] = []
        for name in Self.notifications {
            var token: Int32 = 0
            let status = notify_register_dispatch(name, &token, .main) { _ in
                MainActor.assumeIsolated { handler() }
            }
            if status == 0 { tokens.append(token) }
        }
        let registered = tokens
        return BatteryObservation {
            for token in registered { notify_cancel(token) }
        }
    }
}
#endif

#if os(macOS)
import Foundation
import IOKit
import IOKit.ps
import notify
import BatteryCore

/// Reads the internal battery through IOKit.
///
/// Three sources are combined:
/// - `AppleSmartBattery` IORegistry properties — the gauge's raw data (capacities in
///   `BatteryData`, cycles, charger and power telemetry; macOS 27 publishes no temperature or
///   cell voltages). Readable without privileges.
/// - `IOPSCopyPowerSourcesInfo` — the public power-source API that backs the menu bar
///   (percent, time remaining, health condition).
/// - `IOPSCopyExternalPowerAdapterDetails` — the connected adapter.
///
/// Changes are pushed through notify(3) power-source keys, so no polling is needed unless the UI
/// shows live current/power values.
@MainActor
public final class MacBatteryProvider: BatteryProvider {
    public init() {}

    public func read() -> BatteryReading? {
        let smartBattery = Self.smartBatteryProperties()
        let powerSource = Self.internalBatteryDescription()
        guard smartBattery != nil || powerSource != nil else { return nil }

        var reading = BatteryReading(
            smartBattery: smartBattery ?? [:],
            powerSource: powerSource ?? [:],
            adapterDetails: Self.externalAdapterDetails() ?? [:],
            timestamp: Date()
        )
        reading.snapshot.applySystemState()
        return reading
    }

    /// notify(3) keys from IOPowerSources.h: `kIOPSNotifyAnyPowerSource` and
    /// `kIOPSNotifyTimeRemaining` (the key `IOPSNotificationCreateRunLoopSource` uses internally).
    static let powerSourceNotifications = [
        "com.apple.system.powersources",
        "com.apple.system.powersources.timeremaining",
    ]

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        let removeObservers = observeNotifications(systemStateNotifications, handler: handler)

        // notify(3) rather than IOPSNotificationCreateRunLoopSource: invalidating that run loop
        // source never releases its CFMachPort, so every stop() would leak a port and a
        // notifyd registration. notify_cancel tears down deterministically.
        var tokens: [Int32] = []
        for name in Self.powerSourceNotifications {
            var token: Int32 = 0
            let status = notify_register_dispatch(name, &token, .main) { _ in
                MainActor.assumeIsolated { handler() }
            }
            if status == 0 { tokens.append(token) }
        }
        let registered = tokens
        return BatteryObservation {
            for token in registered { notify_cancel(token) }
            removeObservers()
        }
    }

    // MARK: - IOKit

    static func smartBatteryProperties() -> PropertyDictionary? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
            let dictionary = properties?.takeRetainedValue() as? [String: Any]
        else { return nil }
        return PropertyValue.dictionary(fromAny: dictionary)
    }

    static func internalBatteryDescription() -> PropertyDictionary? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?
                    .takeUnretainedValue() as? [String: Any],
                description["Type"] as? String == "InternalBattery"
            else { continue }
            return PropertyValue.dictionary(fromAny: description)
        }
        return nil
    }

    static func externalAdapterDetails() -> PropertyDictionary? {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return PropertyValue.dictionary(fromAny: details)
    }
}
#endif

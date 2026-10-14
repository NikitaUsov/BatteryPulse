#if os(macOS)
import Foundation
import IOKit
import IOKit.ps
import BatteryCore

/// Reads the internal battery through IOKit.
///
/// Three sources are combined:
/// - `AppleSmartBattery` IORegistry properties — the gauge's raw data (capacities, cycles,
///   cells, temperature, telemetry). Readable without privileges and inside the App Sandbox.
/// - `IOPSCopyPowerSourcesInfo` — the public power-source API that backs the menu bar
///   (percent, time remaining, health condition).
/// - `IOPSCopyExternalPowerAdapterDetails` — the connected adapter.
///
/// Changes are pushed via the `com.apple.system.powersources` notification, so no polling is
/// needed unless the UI shows live current/power values.
@MainActor
public final class MacBatteryProvider: BatteryProvider {
    /// `kIOPSNotifyAnyPowerSource`: posted on any power-source update.
    static let anyPowerSourceNotification = "com.apple.system.powersources"

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

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        let removeObservers = observeNotifications(systemStateNotifications, handler: handler)

        var token: Int32 = 0
        let status = notify_register_dispatch(Self.anyPowerSourceNotification, &token, .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        let registered = status == 0
        return BatteryObservation { [token] in
            if registered { notify_cancel(token) }
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
            guard let description = IOPSGetPowerSourceDescription(info, source)?
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

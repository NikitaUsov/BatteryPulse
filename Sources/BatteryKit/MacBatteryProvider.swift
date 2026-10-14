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
/// Changes are pushed by `IOPSNotificationCreateRunLoopSource`, so no polling is needed unless
/// the UI shows live current/power values.
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

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        let removeObservers = observeNotifications(systemStateNotifications, handler: handler)

        // The C callback can't capture, so the handler travels through the context pointer.
        let context = Unmanaged.passRetained(HandlerBox(handler))
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let box = Unmanaged<HandlerBox>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { box.handler() }
        }
        guard
            let source = IOPSNotificationCreateRunLoopSource(callback, context.toOpaque())?
                .takeRetainedValue()
        else {
            context.release()
            return BatteryObservation(onCancel: removeObservers)
        }
        // Common modes keep updates flowing while a menu is open (event-tracking mode).
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        let resources = UncheckedSendable(value: (source, context))
        return BatteryObservation {
            CFRunLoopSourceInvalidate(resources.value.0)
            resources.value.1.release()
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

private final class HandlerBox: Sendable {
    let handler: @MainActor @Sendable () -> Void

    init(_ handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }
}
#endif

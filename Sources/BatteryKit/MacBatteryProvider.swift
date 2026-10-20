#if os(macOS)
import Foundation
import IOKit
import IOKit.ps
import notify
import BatteryCore

/// Reads the internal battery through IOKit.
///
/// Four sources are combined:
/// - `AppleSmartBattery` IORegistry properties — the gauge's raw data (capacities in
///   `BatteryData`, cycles, charger and power telemetry) — plus the entries below it, where
///   macOS 27 keeps the temperature and cell voltages (``RegistryChildren``). Readable without
///   privileges.
/// - `IOPSCopyPowerSourcesInfo` — the public power-source API that backs the menu bar
///   (percent, time remaining, health condition).
/// - `IOPSCopyExternalPowerAdapterDetails` — the connected adapter.
/// - The SMC's battery keys (``SMCBattery``), a second source for the temperature and cell
///   voltages, read at most every ``smcInterval`` seconds.
///
/// Changes are pushed through notify(3) power-source keys, so no polling is needed unless the UI
/// shows live current/power values.
@MainActor
public final class MacBatteryProvider: BatteryProvider {
    /// The SMC's current and voltage are live (the registry's copy can lag a minute), so they
    /// are read again for any refresh more than this far apart.
    public static let smcInterval: TimeInterval = 2

    private let smc: SMCClient?
    private var smcCache: (date: Date, values: PropertyDictionary)?
    /// The SMC's live pack voltage and current, the `smc.power` part of a read.
    private static let smcPowerKeys: Set<SMCFourCC> = ["B0AV", "B0AC"]

    /// - Parameter readsSMC: `false` where the SMC can't be opened anyway, such as in the
    ///   sandboxed widget, so no attempt shows up as a sandbox violation.
    public init(readsSMC: Bool = true) {
        smc = readsSMC ? SMCClient() : nil
    }

    public func read() -> BatteryReading? {
        let interval = Diagnostics.begin("read")
        defer { interval.end() }
        let smartBattery = Diagnostics.measure("registry") { Self.smartBatteryProperties() }
        let powerSource = Diagnostics.measure("iops") { Self.internalBatteryDescription() }
        guard smartBattery != nil || powerSource != nil else { return nil }

        let adapterDetails = Diagnostics.measure("adapter") { Self.externalAdapterDetails() }
        let smcCapture = smartBattery == nil ? [:] : smcValues()
        let parse = Diagnostics.begin("parse")
        var reading = BatteryReading(
            smartBattery: smartBattery ?? [:],
            powerSource: powerSource ?? [:],
            adapterDetails: adapterDetails ?? [:],
            smc: smcCapture,
            timestamp: Date()
        )
        reading.snapshot.applySystemState()
        parse.end()
        return reading
    }

    private func smcValues() -> PropertyDictionary {
        guard let smc else { return [:] }
        if let smcCache, Date().timeIntervalSince(smcCache.date) < Self.smcInterval { return smcCache.values }
        // The same keys as one read, timed as the live pair and the rest; the order doesn't matter.
        let power = Diagnostics.measure("smc.power") { smc.read(SMCBattery.keys.filter(Self.smcPowerKeys.contains)) }
        let other = Diagnostics.measure("smc.other") {
            smc.read(SMCBattery.keys.filter { !Self.smcPowerKeys.contains($0) })
        }
        let values = SMCBattery.capture(power + other)
        smcCache = (Date(), values)
        return values
    }

    /// notify(3) keys from IOPowerSources.h: `kIOPSNotifyAnyPowerSource` and
    /// `kIOPSNotifyTimeRemaining` (the key `IOPSNotificationCreateRunLoopSource` uses internally).
    static let powerSourceNotifications = [
        "com.apple.system.powersources",
        "com.apple.system.powersources.timeremaining",
    ]

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        // Apple: "you must access the thermalState prior to registering for the notification."
        _ = ProcessInfo.processInfo.thermalState
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

        guard var dictionary = properties(of: service) else { return nil }
        let children = Diagnostics.measure("children") { childProperties(of: service, depth: 1) }
        if !children.isEmpty { dictionary[RegistryChildren.childrenKey] = children }
        return PropertyValue.dictionary(fromAny: dictionary)
    }

    static func properties(of entry: io_registry_entry_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return nil
        }
        return properties?.takeRetainedValue() as? [String: Any]
    }

    /// The entries below `entry` in the IOService plane, shaped like `ioreg -a -l` prints them:
    /// each with its class under `IOObjectClass` and its own children under
    /// `IORegistryEntryChildren`. `IORegistryEntryCreateCFProperties` never includes them.
    static func childProperties(of entry: io_registry_entry_t, depth: Int) -> [[String: Any]] {
        guard depth <= RegistryChildren.maximumDepth else { return [] }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var children: [[String: Any]] = []
        var child = IOIteratorNext(iterator)
        while child != 0 {
            if var dictionary = properties(of: child) {
                if let className = IOObjectCopyClass(child)?.takeRetainedValue() {
                    dictionary[RegistryChildren.classKey] = className as String
                }
                let grandchildren = childProperties(of: child, depth: depth + 1)
                if !grandchildren.isEmpty { dictionary[RegistryChildren.childrenKey] = grandchildren }
                children.append(dictionary)
            }
            IOObjectRelease(child)
            child = IOIteratorNext(iterator)
        }
        return children
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

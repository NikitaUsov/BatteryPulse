#if os(macOS)
import Foundation
import IOKit
import IOKit.ps
import BatteryCore
import Synchronization

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
/// - The SMC's battery keys (``SMCBattery``): the live pack voltage and current, and a second
///   source for the temperature and cell voltages. A key takes one round trip of about
///   0.2–0.5 ms, so all 16 take about 3–8 ms (derived, not measured). ``read()`` asks for every
///   key; ``read(scope:)`` with `.live` asks only for the live pair and keeps the rest from the
///   read that last asked for them (``SMCValueCache``).
///
/// Changes are pushed through notify(3) power-source keys, so no polling is needed unless the UI
/// shows live current/power values.
///
/// A read may run on any thread (``readNonisolated(scope:)``): what the provider keeps between
/// reads, the SMC's values and its connection, is behind locks, so a caller such as
/// ``BatteryMonitor`` can read off the main actor. Only ``observeChanges(_:)`` belongs to the main
/// actor.
public nonisolated final class MacBatteryProvider: BatteryProvider, NonisolatedBatteryReader {
    private let smc: SMCClient?
    /// Held for a read's whole SMC part, so a second read at the same time reuses its values
    /// (``SMCValueCache/minimumAge``) instead of asking the SMC again.
    private let smcCache = Mutex(SMCValueCache())

    /// - Parameter readsSMC: `false` where the SMC can't be opened anyway, such as in the
    ///   sandboxed widget, so no attempt shows up as a sandbox violation.
    public init(readsSMC: Bool = true) {
        smc = readsSMC ? SMCClient() : nil
    }

    /// Reads everything, every SMC key included, as `bpulse` and the widget always have. A read
    /// within ``SMCValueCache/minimumAge`` of the last one reuses its SMC values.
    public nonisolated func read() -> BatteryReading? {
        readNonisolated(scope: .full)
    }

    public nonisolated func read(scope: BatteryReadScope) -> BatteryReading? {
        readNonisolated(scope: scope)
    }

    /// The provider itself: every read may run off the main actor.
    public nonisolated var nonisolatedReader: (any NonisolatedBatteryReader)? {
        self
    }

    /// ``read(scope:)`` from any thread, for callers off the main actor.
    public nonisolated func readNonisolated(scope: BatteryReadScope) -> BatteryReading? {
        let interval = Diagnostics.begin("read")
        defer { interval.end() }
        let smartBattery = Diagnostics.measure("registry") { Self.smartBatteryProperties() }
        let powerSource = Diagnostics.measure("iops") { Self.internalBatteryDescription() }
        guard smartBattery != nil || powerSource != nil else { return nil }

        let adapterDetails = Diagnostics.measure("adapter") { Self.externalAdapterDetails() }
        let smcCapture = smartBattery == nil ? [:] : smcValues(readsOtherKeys: scope == .full)
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

    /// The SMC's values after asking for the groups that are due: the live pair (`smc.power`) and,
    /// for a full read, the rest (`smc.other`).
    private func smcValues(readsOtherKeys: Bool) -> PropertyDictionary {
        guard let smc else { return [:] }
        return smcCache.withLock { cache in
            let now = ContinuousClock.now
            for group in cache.groupsToRead(at: now, readsOtherKeys: readsOtherKeys) {
                let name: StaticString = group == .live ? "smc.power" : "smc.other"
                let answers = Diagnostics.measure(name) { smc.read(group.keys) }
                cache.store(answers, for: group, at: now)
            }
            return cache.capture
        }
    }

    /// notify(3) keys from IOPowerSources.h: `kIOPSNotifyAnyPowerSource` and
    /// `kIOPSNotifyTimeRemaining` (the key `IOPSNotificationCreateRunLoopSource` uses internally).
    static let powerSourceNotifications = [
        "com.apple.system.powersources",
        "com.apple.system.powersources.timeremaining",
    ]

    @MainActor
    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        // Apple: "you must access the thermalState prior to registering for the notification."
        _ = ProcessInfo.processInfo.thermalState
        let removeObservers = observeNotifications(systemStateNotifications, handler: handler)
        let cancelPowerSources = observeNotifyKeys(Self.powerSourceNotifications, handler: handler)
        return BatteryObservation {
            cancelPowerSources()
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
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        let battery = powerSourceDescriptions(in: info).first {
            $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
        return PropertyValue.dictionary(fromAny: battery)
    }

    static func externalAdapterDetails() -> PropertyDictionary? {
        guard let details = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return PropertyValue.dictionary(fromAny: details)
    }
}
#endif

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
///   0.2–0.5 ms, so all 16 take about 3–8 ms (derived, not measured).
///
/// ``read()`` fetches everything. ``read(scope:)`` makes two separate decisions
/// (``BatteryReadScope``): without ``BatteryReadScope/rereadsRegistry`` it reuses the registry,
/// IOPS and adapter dictionaries of the read that last fetched them and found a battery, about
/// three quarters of a read on the M5 (``RegistryReadPolicy``); without
/// ``BatteryReadScope/readsAllSMCKeys`` it asks the SMC only for the live pair and keeps the rest
/// from the read that last asked for them (``SMCValueCache``).
///
/// Changes are pushed through a notify(3) power-source key (``powerSourceNotifications``), so no
/// polling is needed unless the UI shows live current/power values.
///
/// A read may run on any thread (``readNonisolated(scope:)``): what the provider keeps between
/// reads, the registry's dictionaries, the SMC's values and its connection, is behind locks, so a
/// caller such as ``BatteryMonitor`` can read off the main actor. Only ``observeChanges(_:)``
/// belongs to the main actor.
public nonisolated final class MacBatteryProvider: BatteryProvider, NonisolatedBatteryReader {
    private let smc: SMCClient?
    /// Held for a read's whole SMC part, so a second read at the same time reuses its values
    /// (``SMCValueCache/minimumAge``) instead of asking the SMC again.
    private let smcCache = Mutex(SMCValueCache())
    /// The dictionaries of the read that last fetched the registry and found a battery, for the
    /// reads that reuse them; `nil` before one has.
    private let registryCache = Mutex<RegistryCapture?>(nil)

    /// - Parameter readsSMC: `false` where the SMC can't be opened anyway, such as in the
    ///   sandboxed widget, so no attempt shows up as a sandbox violation.
    public init(readsSMC: Bool = true) {
        smc = readsSMC ? SMCClient() : nil
    }

    /// Reads everything, the registry and every SMC key included, as `bpulse` and the widget
    /// always have. A read within ``SMCValueCache/minimumAge`` of the last one reuses its SMC
    /// values.
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
        // A read that may reuse the registry fetches it until one has found a battery. The
        // signpost names what the read does.
        let cached = scope.rereadsRegistry ? nil : registryCache.withLock { $0 }
        let done = BatteryReadScope(rereadsRegistry: cached == nil, readsAllSMCKeys: scope.readsAllSMCKeys)
        let interval = Diagnostics.begin("read", trigger: done.signpostName)
        defer { interval.end() }
        let registry = cached ?? fetchRegistry()
        guard registry.hasBattery else { return nil }

        let smcCapture = registry.smartBattery == nil ? [:] : smcValues(readsOtherKeys: scope.readsAllSMCKeys)
        let parse = Diagnostics.begin("parse")
        var reading = BatteryReading(registry: registry, smc: smcCapture, timestamp: Date())
        reading.snapshot.applySystemState()
        parse.end()
        return reading
    }

    /// Fetches the registry, IOPS and adapter dictionaries, and keeps them for the reads that
    /// reuse them while they show a battery.
    private func fetchRegistry() -> RegistryCapture {
        var registry = RegistryCapture(
            smartBattery: Diagnostics.measure("registry") { Self.smartBatteryProperties() },
            powerSource: Diagnostics.measure("iops") { Self.internalBatteryDescription() })
        if registry.hasBattery {
            registry.adapterDetails = Diagnostics.measure("adapter") { Self.externalAdapterDetails() }
        }
        let kept = registry.hasBattery ? registry : nil
        registryCache.withLock { $0 = kept }
        return registry
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

    /// The notify(3) key from IOPowerSources.h that powerd posts whenever any power source changes,
    /// the registry's battery data included: `kIOPSNotifyAnyPowerSource`. Not
    /// `kIOPSNotifyTimeRemaining`, the key `IOPSNotificationCreateRunLoopSource` uses internally:
    /// powerd posts it in the same pass, just before this one, so it only told of the same change
    /// twice. On the M5 (macOS 27), every one was followed by this key within 10 ms, in 2 hours on
    /// battery and 1 hour charging.
    static let powerSourceNotifications = ["com.apple.system.powersources"]

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

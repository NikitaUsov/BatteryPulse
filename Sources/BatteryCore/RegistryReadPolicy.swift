import Foundation

/// When a battery read fetches the registry again: the `AppleSmartBattery` entry with its children,
/// and the power-source (IOPS) and adapter dictionaries read with it, about three quarters of a
/// read on the M5.
///
/// powerd posts the "any power source" notification whenever the registry has new data, so the
/// read that follows a notification sees every change, and a poll between two changes would fetch
/// the same dictionaries again. So a poll reuses the dictionaries of the read that last fetched
/// them and asks the SMC only for what it polls for (``SMCReadPolicy``). It still fetches them
/// while a page that shows their values (Power, Raw Data) is on screen, and once they are
/// ``safetyNetAge`` old, for a notification that never came. Every other read fetches them: a
/// notification's, a follow-up after the adapter was plugged in or out, the launch, the history's
/// sample (which covers wake), Demo Mode's and a manual one.
public struct RegistryReadPolicy: Sendable, Equatable {
    /// The one switch: whether the app's polls may reuse the registry. `false` fetches it on every
    /// read, as 0.6.1 did. Never a setting.
    public static let cachesOnPolls = true

    /// How old the reused dictionaries may get before a poll fetches them again. On the M5 (macOS
    /// 27), every change of the registry's `UpdateTime` came with a notification, in 2 hours on
    /// battery and 1 hour charging, so a missed one is the exception this only bounds.
    public static let defaultSafetyNetAge: Duration = .seconds(300)

    /// The app's: polls reuse the registry while ``cachesOnPolls`` is on.
    public static let app = RegistryReadPolicy(cachesOnPolls: cachesOnPolls)

    /// Whether polls may reuse the registry; `false` fetches it on every read.
    public var cachesOnPolls: Bool
    /// How old the reused dictionaries may get before a poll fetches them again.
    public var safetyNetAge: Duration

    public init(cachesOnPolls: Bool, safetyNetAge: Duration = Self.defaultSafetyNetAge) {
        self.cachesOnPolls = cachesOnPolls
        self.safetyNetAge = safetyNetAge
    }

    /// Whether a read fetches the registry again.
    ///
    /// - Parameters:
    ///   - isPoll: the read is a live-refresh poll, or serves only polls; every other read fetches
    ///     the registry.
    ///   - age: how long ago a read last fetched it; `nil` before the first.
    ///   - isShown: a page that shows the registry's values (Power, Raw Data) is on screen.
    /// - Returns: `true` to fetch the registry, `false` to reuse the last read's.
    public func rereadsRegistry(isPoll: Bool, age: Duration?, isShown: Bool) -> Bool {
        guard cachesOnPolls, isPoll, let age, !isShown else { return true }
        return age >= safetyNetAge
    }
}

/// What a Mac's battery read fetches besides the SMC: the `AppleSmartBattery` properties with its
/// children, the internal battery's power-source description and the adapter details, each `nil`
/// where the lookup failed. A poll may reuse an earlier read's (``RegistryReadPolicy``).
public struct RegistryCapture: Sendable, Equatable {
    public var smartBattery: PropertyDictionary?
    public var powerSource: PropertyDictionary?
    public var adapterDetails: PropertyDictionary?

    public init(
        smartBattery: PropertyDictionary? = nil,
        powerSource: PropertyDictionary? = nil,
        adapterDetails: PropertyDictionary? = nil
    ) {
        self.smartBattery = smartBattery
        self.powerSource = powerSource
        self.adapterDetails = adapterDetails
    }

    /// Whether the registry entry or the power source was found: a Mac without either has no
    /// battery.
    public var hasBattery: Bool {
        smartBattery != nil || powerSource != nil
    }
}

extension BatteryReading {
    /// Parses `registry`, freshly fetched or reused, with the SMC's values in `smc`, which may be
    /// newer: a reused registry keeps its own values, and the SMC's live voltage and current come
    /// first where the parser prefers them.
    public init(registry: RegistryCapture, smc: PropertyDictionary, timestamp: Date) {
        self.init(
            smartBattery: registry.smartBattery ?? [:],
            powerSource: registry.powerSource ?? [:],
            adapterDetails: registry.adapterDetails ?? [:],
            smc: smc,
            timestamp: timestamp
        )
    }
}

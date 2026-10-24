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

    /// The app's: polls reuse the registry while ``cachesOnPolls-type.property`` is on.
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

/// Spots a registry update that no notification announced, the case a poll that reuses the
/// registry would miss until a read fetches it again: ``RegistryReadPolicy``'s field signal (the
/// `registry.missed` event).
///
/// The battery monitor counts every change notification (``notificationArrived()``), takes a
/// ``mark`` when a read that fetches the registry begins, and hands over what the read found
/// (``fetched(updated:mark:)``). An update is missed when the gauge's update time differs from the
/// last fetch's and no notification arrived since that fetch began, so a notification that comes
/// while a read is under way still counts for the change that read saw. Any change notification
/// counts, Low Power Mode's and thermal ones too, so one of them can hide a miss; a read that sees
/// a change and lands before the change's notification arrives counts one too many.
public struct RegistryUpdateWatch: Sendable, Equatable {
    private struct Fetch: Sendable, Equatable {
        let updated: Date
        let mark: Int
    }

    private var notifications = 0
    private var last: Fetch?

    public init() {}

    /// Counts a change notification.
    public mutating func notificationArrived() {
        notifications += 1
    }

    /// The notifications so far, for a read that fetches the registry to take when it begins.
    public var mark: Int {
        notifications
    }

    /// Takes the gauge's update time (`UpdateTime`) that a read found, which began at `mark`.
    /// Returns `true` when the update time changed since the last fetch although no notification
    /// arrived since that one began. A read without an update time changes nothing.
    public mutating func fetched(updated: Date?, mark: Int) -> Bool {
        guard let updated else { return false }
        let previous = last
        last = Fetch(updated: updated, mark: mark)
        guard let previous else { return false }
        return updated != previous.updated && notifications == previous.mark
    }

    /// Forgets the last fetch, after a time when notifications weren't heard: Demo Mode, or a
    /// stopped monitor.
    public mutating func reset() {
        last = nil
    }
}

import Foundation

/// Something worth a notification.
public enum BatteryAlert: String, Sendable, CaseIterable {
    /// Charging reached the user's limit, so the Mac can be unplugged.
    case chargeLimitReached
    /// On battery and down to the user's threshold.
    case lowBattery
    /// macOS reports a battery condition other than normal.
    case serviceRecommended
    /// The Mac is under heavy thermal pressure.
    case highTemperature
}

/// Which alerts the user wants. Percentages are `nil` when the alert is off.
public struct AlertSettings: Sendable, Equatable {
    public var chargeLimit: Int?
    public var lowBattery: Int?
    public var serviceRecommended: Bool
    public var highTemperature: Bool
    /// An accessory's threshold (``AccessoryAlerts``); ``BatteryAlerts/evaluate(_:settings:state:)``
    /// ignores it.
    public var accessoryLowBattery: Int?

    public init(
        chargeLimit: Int? = nil, lowBattery: Int? = nil, serviceRecommended: Bool = false,
        highTemperature: Bool = false,
        accessoryLowBattery: Int? = nil
    ) {
        self.chargeLimit = chargeLimit
        self.lowBattery = lowBattery
        self.serviceRecommended = serviceRecommended
        self.highTemperature = highTemperature
        self.accessoryLowBattery = accessoryLowBattery
    }

    public var isAnyEnabled: Bool {
        chargeLimit != nil || lowBattery != nil || serviceRecommended || highTemperature || accessoryLowBattery != nil
    }
}

/// What has already been announced, so each alert fires once and re-arms only after the battery
/// has clearly moved away from the threshold. Saved between launches.
public struct AlertState: Sendable, Equatable, Codable {
    public var chargeLimitArmed = true
    public var lowBatteryArmed = true
    public var serviceAnnounced = false
    public var highTemperatureArmed = true
    public var lastHighTemperatureAlert: Date?

    public init() {}
}

public enum BatteryAlerts {
    /// How far the charge has to move back before a percentage alert can fire again. macOS's own
    /// Charge Limit resumes charging after the same 5 percent.
    public static let rearmMargin = 5.0
    /// The shortest time between two heat alerts, so a Mac hovering around the threshold doesn't
    /// keep notifying.
    public static let highTemperatureCooldown: TimeInterval = 60 * 60

    /// The alerts `snapshot` calls for, updating `state`.
    public static func evaluate(
        _ snapshot: BatterySnapshot, settings: AlertSettings, state: inout AlertState
    ) -> [BatteryAlert] {
        var alerts: [BatteryAlert] = []
        let percent = snapshot.chargePercent
        let pluggedIn = snapshot.isExternalPowerConnected == true

        // Charge limit: while plugged in, once the charge reaches the limit.
        if let limit = settings.chargeLimit.map(Double.init), let percent {
            let reached = pluggedIn && (percent >= limit || snapshot.chargeState == .charged)
            if reached, state.chargeLimitArmed {
                alerts.append(.chargeLimitReached)
                state.chargeLimitArmed = false
            } else if !pluggedIn || (!reached && percent <= limit - rearmMargin) {
                // Re-arm only once the alert's own condition is gone: macOS can report a held
                // charge as fully charged well below the user's limit.
                state.chargeLimitArmed = true
            }
        }

        // Low battery: on battery, once the charge falls to the threshold.
        if let threshold = settings.lowBattery.map(Double.init), let percent {
            if !pluggedIn, percent <= threshold, state.lowBatteryArmed {
                alerts.append(.lowBattery)
                state.lowBatteryArmed = false
            } else if pluggedIn || percent >= threshold + rearmMargin {
                state.lowBatteryArmed = true
            }
        }

        // Service: once each time the condition turns abnormal.
        if settings.serviceRecommended {
            let normal = snapshot.healthCondition.map { ["Normal", "Good"].contains($0) } ?? true
            if !normal, !state.serviceAnnounced {
                alerts.append(.serviceRecommended)
                state.serviceAnnounced = true
            } else if normal {
                state.serviceAnnounced = false
            }
        }

        // Heat: on serious or critical thermal state, again only after it cooled to normal and
        // an hour has passed.
        if settings.highTemperature {
            if snapshot.thermalState == .serious || snapshot.thermalState == .critical {
                let cooledDown =
                    state.lastHighTemperatureAlert.map {
                        snapshot.timestamp.timeIntervalSince($0) >= highTemperatureCooldown || snapshot.timestamp < $0
                    } ?? true
                if state.highTemperatureArmed, cooledDown {
                    alerts.append(.highTemperature)
                    state.highTemperatureArmed = false
                    state.lastHighTemperatureAlert = snapshot.timestamp
                }
            } else if snapshot.thermalState == .nominal {
                state.highTemperatureArmed = true
            }
        }
        return alerts
    }
}

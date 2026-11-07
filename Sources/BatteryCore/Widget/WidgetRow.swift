import Foundation

/// One detail as the widget shows it. The value is pre-formatted, or a word the widget maps to
/// its catalog key; the label stays the field, which the widget maps to its `LocalizedStringKey`,
/// so every widget string is a literal the localization test sees.
public struct WidgetRow: Sendable, Equatable {
    public var field: BatteryWidgetField
    public var value: WidgetValue
    /// Maximum capacity and condition warn as they do in the app; the other fields are normal.
    public var tier: BatteryPresentation.LevelTier

    init(field: BatteryWidgetField, value: WidgetValue, tier: BatteryPresentation.LevelTier = .normal) {
        self.field = field
        self.value = value
        self.tier = tier
    }

    /// The symbol that says what the tier's colour says, so colour is never the only signal.
    public var cue: WidgetCue? { WidgetCue(tier) }

    /// `field`'s row for `snapshot`, or `nil` when the reading doesn't have it: a Mac without a
    /// pack temperature, an adapter while on battery. `time` is the entry's time text, which only
    /// the planner knows; `feed` the app's, whose fields show "—" without it.
    init?(
        _ field: BatteryWidgetField, snapshot s: BatterySnapshot, time: WidgetTimeText?, formatter f: BatteryFormatter,
        feed: WidgetFeed? = nil
    ) {
        let value: WidgetValue
        var tier = BatteryPresentation.LevelTier.normal
        switch field {
        case .state:
            value = .state(WidgetStateWord(s))
        case .time:
            guard let time else { return nil }
            value = .time(time)
        case .maximumCapacity:
            guard let health = s.healthPercent else { return nil }
            value = .text(f.percent(health))
            tier = BatteryPresentation.healthTier(for: s)
        case .condition:
            let condition = WidgetCondition(s.healthCondition)
            value = .condition(condition)
            tier = condition.tier
        case .cycleCount:
            guard let cycles = s.cycleCount else { return nil }
            value = .text(cycles.formatted(.number.locale(f.locale)))
        case .temperature:
            guard let temperature = s.temperatureCelsius else { return nil }
            value = .text(f.celsius(temperature))
        case .adapter:
            guard s.isExternalPowerConnected == true, let watts = s.adapter?.watts else { return nil }
            value = .text(f.watts(Double(watts), fractionDigits: 0))
        case .systemLoad:
            guard let load = s.systemLoadWatts else { return nil }
            value = .text(f.watts(load))
        case .batteryPower:
            guard let watts = s.batteryPowerWatts else { return nil }
            value = .text(f.watts(watts, signed: true))
        case .adapterInput:
            // As the Power page shows it: only while plugged in and drawing power.
            guard s.isExternalPowerConnected == true, let input = s.systemPowerInWatts, input > 0 else { return nil }
            value = .text(f.watts(input))
        case .lowPowerMode:
            guard let on = s.isLowPowerModeEnabled else { return nil }
            value = .onOff(on)
        case .remainingCapacity:
            guard let remaining = s.currentCapacityMAh else { return nil }
            value = .text(f.milliampHours(remaining))
        case .cycleLifeUsed:
            guard let cycles = s.cycleCount else { return nil }
            let rated = BatteryPresentation.ratedCycles(s.designCycleCount) ?? BatteryPresentation.fallbackRatedCycles
            value = .text(f.percent(Double(cycles) / Double(rated) * 100))
        case .cellBalance:
            guard let spread = s.cellVoltageSpreadMV else { return nil }
            value = .text(f.millivolts(spread))
        case .voltage:
            guard let voltage = s.voltageMV else { return nil }
            value = .text(f.volts(millivolts: voltage))
        case .systemChargeLimit:
            // As Power's row: the number from the app's feed (powerd's file, which the sandbox
            // can't read) while the feed is current at this reading, the hold from the reading.
            let limit = feed.flatMap { $0.isOutdated(at: s.timestamp) ? nil : $0.systemChargeLimitPercent }
            guard let row = SystemChargeLimitRow(s, percent: limit) else { return nil }
            value =
                switch row {
                case .limit(let percent): .text(f.percent(Double(percent)))
                case .reached(let percent): .limitReached(f.percent(Double(percent)))
                case .reachedUnknown: .reached
                }
        case .averageDrain:
            value = .averageDrain(feed?.statistics24h?.averageDrainPercentPerHour, f)
        case .timeOnBattery:
            // Since the unplug the feed last saw, while this reading is on battery too.
            if s.isExternalPowerConnected != true, s.chargeState == .discharging, let since = feed?.onBatterySince {
                value = .since(since)
            } else {
                value = .text(WidgetValue.missing)
            }
        }
        self.init(field: field, value: value, tier: tier)
    }
}

/// A row's value.
public enum WidgetValue: Sendable, Equatable {
    /// Numbers and units, shown verbatim.
    case text(String)
    case state(WidgetStateWord)
    case condition(WidgetCondition)
    /// "On" or "Off".
    case onOff(Bool)
    case time(WidgetTimeText)
    /// "Reached": the Charge Limit holds the charge, its number unknown.
    case reached
    /// "%@, reached", the limit pre-formatted: the Charge Limit holds the charge at it.
    case limitReached(String)
    /// "%@ per hour", the value pre-formatted: the average drain.
    case perHour(String)
    /// The time since a moment, which the system counts up between reloads with the widget's one
    /// self-updating text: the time on battery since the last unplug.
    case since(Date)
}

/// The Mac battery's state in the words the widget and the app use, decided once for both so
/// the two can't drift apart.
public enum WidgetStateWord: Sendable, Equatable, CaseIterable {
    case charging, onBattery, fullyCharged, chargingOnHold
    /// "Charged to limit": macOS's Charge Limit holds the charge
    /// (``BatterySnapshot/isAtSystemChargeLimit``). Apple's battery menu says "Charged to 80%
    /// Limit"; the words leave the number out, since the reading alone doesn't have it: the Charge
    /// limit field and Power show it when BatteryPulse knows it.
    case chargedToLimit
    case notCharging, unknown

    public init(_ s: BatterySnapshot) {
        self =
            switch s.chargeState {
            case .charging: .charging
            case .discharging: .onBattery
            case .charged: .fullyCharged
            case .notCharging:
                if s.isOptimizedChargingEngaged == true {
                    .chargingOnHold
                } else if s.isAtSystemChargeLimit {
                    .chargedToLimit
                } else {
                    .notCharging
                }
            case .unknown: .unknown
            }
    }
}

/// The condition macOS reports, as the app words it; no condition (or an empty one) is Normal.
public enum WidgetCondition: Sendable, Equatable {
    case normal, fair, poor, checkBattery, serviceRecommended
    /// A condition the app has no words for, shown as macOS reports it.
    case other(String)

    init(_ raw: String?) {
        self =
            switch raw {
            case nil, "", "Normal", "Good": .normal
            case "Fair": .fair
            case "Poor": .poor
            case "Check Battery": .checkBattery
            case "Service Recommended": .serviceRecommended
            case let other?: .other(other)
            }
    }

    /// The tier ``BatteryPresentation/healthTier(for:)`` gives the condition alone.
    var tier: BatteryPresentation.LevelTier {
        switch self {
        case .normal: .normal
        case .fair, .serviceRecommended: .low
        case .poor, .checkBattery: .critical
        case .other(let raw): raw == "Permanent Battery Failure" ? .critical : .normal
        }
    }
}

/// A symbol beside a value whose tier isn't normal, in every colour style and rendering mode
/// (HIG: convey meaning without relying on colour alone).
public enum WidgetCue: String, Sendable, CaseIterable {
    case low, critical

    init?(_ tier: BatteryPresentation.LevelTier) {
        switch tier {
        case .normal: return nil
        case .low: self = .low
        case .critical: self = .critical
        }
    }

    public var symbolName: String {
        switch self {
        case .low: "exclamationmark.circle"
        case .critical: "exclamationmark.triangle.fill"
        }
    }
}

/// What the widget raises in every size and layout, with a symbol and words: a condition other
/// than Normal, or a thermal state of serious or worse ("High", "Critical" in the app's words).
/// Heat comes first: it is the one to act on now.
public enum WidgetAttention: Sendable, Equatable {
    case heat(ThermalState)
    case condition(WidgetCondition)

    init?(_ s: BatterySnapshot) {
        if let thermal = s.thermalState, thermal == .serious || thermal == .critical {
            self = .heat(thermal)
            return
        }
        let condition = WidgetCondition(s.healthCondition)
        guard condition != .normal else { return nil }
        self = .condition(condition)
    }

    public var symbolName: String {
        switch self {
        case .heat: "thermometer.high"
        case .condition: "exclamationmark.triangle"
        }
    }

    var isHeat: Bool {
        if case .heat = self { true } else { false }
    }

    var isCondition: Bool {
        if case .condition = self { true } else { false }
    }

    /// The tier its symbol's colour says: critical heat is critical, serious heat low, and a
    /// condition has its own tier.
    public var tier: BatteryPresentation.LevelTier {
        switch self {
        case .heat(let state): state == .critical ? .critical : .low
        case .condition(let condition): condition.tier
        }
    }
}

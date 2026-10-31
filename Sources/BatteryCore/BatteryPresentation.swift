import Foundation

/// Display decisions that don't depend on the UI language. Wording lives in the app's String
/// Catalog; numbers and units go through ``BatteryFormatter``.
public enum BatteryPresentation {
    /// SF Symbol for the current level; the bolt variant while charging.
    public static func symbolName(for s: BatterySnapshot?) -> String {
        symbolName(percent: s?.chargePercent, state: s?.chargeState)
    }

    /// The symbol for a charge and state from any battery (a Mac's, an iPhone's).
    public static func symbolName(percent: Double?, state: ChargeState?) -> String {
        guard let percent else { return "battery.0percent" }
        if state == .charging { return "battery.100percent.bolt" }
        switch percent {
        case 88...: return "battery.100percent"
        case 63..<88: return "battery.75percent"
        case 38..<63: return "battery.50percent"
        case 13..<38: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    /// Battery power below this, in either direction, is noise: the power-flow view hides its
    /// value, its arrow rests (``BatteryMotionKey/flow`` reads idle) and the state reads without
    /// watts. About 12 mA at a MacBook pack's 12–13 V, just above the 10 mA below which the app
    /// treats a current as noise: a full or held battery reads a few mA either way, and a band
    /// narrower than that noise would turn the arrow back and forth every few readings.
    public static let powerFlowDeadBandWatts = 0.15

    /// The rated cycle count a cycle gauge measures against when the battery reports none.
    public static let fallbackRatedCycles = 1000

    /// The battery's own rated cycle count, or `nil` when it reports none or 0. A Mac can report
    /// `DesignCycleCount9C = 0`, which would make a gauge's fraction infinite and its caption
    /// read "of 0 rated".
    public static func ratedCycles(_ design: Int?) -> Int? {
        guard let design, design > 0 else { return nil }
        return design
    }

    /// Level colors used by the app: green above 20 % or while charging, then orange, then red.
    public enum LevelTier: Sendable, Equatable {
        case normal, low, critical
    }

    public static func levelTier(for s: BatterySnapshot) -> LevelTier {
        levelTier(percent: s.chargePercent, state: s.chargeState)
    }

    public static func levelTier(percent: Double?, state: ChargeState) -> LevelTier {
        levelTier(percent: percent, isCharging: state == .charging)
    }

    /// The tier for any battery that reports only whether it charges, such as an accessory's.
    public static func levelTier(percent: Double?, isCharging: Bool) -> LevelTier {
        guard let percent, !isCharging, percent <= 20 else { return .normal }
        return percent > 10 ? .low : .critical
    }

    /// Colour tier for maximum capacity: the condition macOS reports, then the capacity itself
    /// (macOS recommends service below 80 %).
    public static func healthTier(for s: BatterySnapshot) -> LevelTier {
        switch s.healthCondition {
        case "Poor", "Check Battery", "Permanent Battery Failure": return .critical
        case "Fair", "Service Recommended": return .low
        default: break
        }
        guard let health = s.healthPercent else { return .normal }
        return health < 80 ? .low : .normal
    }

    /// Colour tier for an iPhone's or iPad's maximum capacity: a gauge error or a latched
    /// permanent failure, then the capacity (iOS recommends service below 80 %).
    public static func healthTier(device battery: IDeviceBattery) -> LevelTier {
        if battery.errorCondition != nil || (battery.permanentFailureStatus ?? 0) != 0 { return .critical }
        guard let health = battery.maximumCapacityPercent else { return .normal }
        return health < 80 ? .low : .normal
    }
}

/// One flattened raw IORegistry value, e.g. `AppleSmartBattery.BatteryData.DesignCapacity`.
public struct RawEntry: Sendable, Equatable {
    public var path: String
    public var property: PropertyValue

    public init(path: String, property: PropertyValue) {
        self.path = path
        self.property = property
    }

    /// Flattens nested dictionaries and arrays into sorted key paths (`Array[0].Key`).
    public static func flatten(_ dictionary: PropertyDictionary, prefix: String = "") -> [RawEntry] {
        var entries: [RawEntry] = []
        func visit(_ value: PropertyValue, path: String) {
            switch value {
            case .dictionary(let nested) where !nested.isEmpty:
                for (key, value) in nested.sorted(by: { $0.key < $1.key }) {
                    visit(value, path: path.isEmpty ? key : "\(path).\(key)")
                }
            case .array(let items) where !items.isEmpty:
                for (index, item) in items.enumerated() {
                    visit(item, path: "\(path)[\(index)]")
                }
            default:
                entries.append(RawEntry(path: path, property: value))
            }
        }
        visit(.dictionary(dictionary), path: prefix)
        return entries
    }
}

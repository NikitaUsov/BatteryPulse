import Foundation

/// Display decisions that don't depend on the UI language. Wording lives in the app's String
/// Catalog; numbers and units go through ``BatteryFormatter``.
public enum BatteryPresentation {
    /// SF Symbol for the current level; the bolt variant while charging.
    public static func symbolName(for s: BatterySnapshot?) -> String {
        guard let s, let percent = s.chargePercent else { return "battery.0percent" }
        if s.chargeState == .charging { return "battery.100percent.bolt" }
        switch percent {
        case 88...: return "battery.100percent"
        case 63..<88: return "battery.75percent"
        case 38..<63: return "battery.50percent"
        case 13..<38: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    /// Battery power below this, in either direction, is noise: the power-flow view hides its
    /// value and ``BatteryMotionKey/flow`` reads idle.
    public static let powerFlowDeadBandWatts = 0.05

    /// Level colors used by the app: green above 20 % or while charging, then orange, then red.
    public enum LevelTier: Sendable, Equatable {
        case normal, low, critical
    }

    public static func levelTier(for s: BatterySnapshot) -> LevelTier {
        guard let percent = s.chargePercent, s.chargeState != .charging, percent <= 20 else { return .normal }
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
}

/// One flattened raw IORegistry value, e.g. `AppleSmartBattery.BatteryData.DesignCapacity`.
public struct RawEntry: Sendable, Equatable, Identifiable {
    public var path: String
    public var property: PropertyValue
    public var id: String { path }
    public var value: String { property.description }

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

/// Identifiers shared by the app and its widget extension.
public enum BatteryWidgetKind {
    /// The battery widget; the app asks WidgetKit to reload it when the battery changes.
    public static let battery = "io.github.nikitausov.BatteryPulse.battery"
}

/// When the app asks WidgetKit to reload the widget. The budget is about 40–70 reloads a day,
/// so plugging in, unplugging and a change of charge state go through at once, while the
/// percentage only after it moved ``percentStep`` points and ``minimumInterval`` has passed.
public struct WidgetReloadPolicy: Sendable {
    public static let percentStep = 5
    public static let minimumInterval: TimeInterval = 30 * 60

    private struct Shown: Equatable {
        var state: ChargeState
        var isExternalPowerConnected: Bool?
        var percent: Int?
    }

    private var shown: Shown?
    private var lastReload: Date?

    public init() {}

    /// Whether `snapshot` warrants a reload now; records it as shown when it does.
    public mutating func shouldReload(for snapshot: BatterySnapshot, at date: Date) -> Bool {
        let next = Shown(
            state: snapshot.chargeState,
            isExternalPowerConnected: snapshot.isExternalPowerConnected,
            percent: snapshot.chargePercent.map { Int($0.rounded()) })
        guard let shown else {
            record(next, at: date)
            return true
        }
        let stateChanged =
            next.state != shown.state || next.isExternalPowerConnected != shown.isExternalPowerConnected
        let percentMoved = abs((next.percent ?? 0) - (shown.percent ?? 0)) >= Self.percentStep
        let intervalPassed = lastReload.map { date.timeIntervalSince($0) >= Self.minimumInterval } ?? true
        guard stateChanged || (percentMoved && intervalPassed) else { return false }
        record(next, at: date)
        return true
    }

    private mutating func record(_ next: Shown, at date: Date) {
        shown = next
        lastReload = date
    }
}

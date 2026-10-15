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

    /// Level colors used by the app: green above 20 % or while charging, then orange, then red.
    public enum LevelTier: Sendable, Equatable {
        case normal, low, critical
    }

    public static func levelTier(for s: BatterySnapshot) -> LevelTier {
        levelTier(percent: s.chargePercent, state: s.chargeState)
    }

    public static func levelTier(percent: Double?, state: ChargeState) -> LevelTier {
        guard let percent, state != .charging, percent <= 20 else { return .normal }
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

/// The widget's timeline for one reading. The widget shows its estimate as a clock time ("Full
/// at 17:39") so that it stays right between reloads; when that time comes before the next reload,
/// a second entry at that moment drops it, so a time that has passed never stays on screen, and
/// the next reload comes soon after.
public struct WidgetTimelinePlan: Sendable, Equatable {
    /// How often the widget asks for a new reading when the app doesn't ask first; WidgetKit allows
    /// about 40–70 reloads a day.
    public static let refreshInterval: TimeInterval = 30 * 60
    /// The earliest next reload, so an estimate that keeps running out near full charge doesn't
    /// spend the budget.
    public static let minimumReloadInterval: TimeInterval = 5 * 60

    public struct Entry: Sendable, Equatable {
        public var date: Date
        public var showsEstimate: Bool

        public init(date: Date, showsEstimate: Bool) {
            self.date = date
            self.showsEstimate = showsEstimate
        }
    }

    public var entries: [Entry]
    public var nextReload: Date

    public init(snapshot: BatterySnapshot?, at date: Date) {
        let regular = date.addingTimeInterval(Self.refreshInterval)
        let soonest = date.addingTimeInterval(Self.minimumReloadInterval)
        let minutes: Int? =
            switch snapshot?.chargeState {
            case .charging: snapshot?.estimatedTimeToFullMinutes
            case .discharging: snapshot?.estimatedTimeToEmptyMinutes
            default: nil
            }
        guard let minutes else {
            entries = [Entry(date: date, showsEstimate: true)]
            nextReload = regular
            return
        }
        let end = date.addingTimeInterval(Double(minutes) * 60)
        if end >= regular {
            entries = [Entry(date: date, showsEstimate: true)]
            nextReload = regular
        } else if end <= date {
            entries = [Entry(date: date, showsEstimate: false)]
            nextReload = soonest
        } else {
            entries = [Entry(date: date, showsEstimate: true), Entry(date: end, showsEstimate: false)]
            nextReload = max(end, soonest)
        }
    }
}

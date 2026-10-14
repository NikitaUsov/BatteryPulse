import Foundation

/// What the menu bar shows next to the battery icon.
public enum MenuBarStyle: String, Sendable, CaseIterable, Codable {
    case percent
    case power
    case percentAndPower
    case iconOnly

    /// Power changes continuously, so these styles need periodic refreshes.
    public var showsPower: Bool {
        self == .power || self == .percentAndPower
    }
}

/// How the battery symbol appears in the menu bar.
public enum MenuBarIconStyle: String, Sendable, CaseIterable, Codable {
    case standard
    case large
    case hidden
}

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

    /// The icon can only be hidden when there is text to show instead; an empty status item
    /// would leave nothing to click.
    public static func showsIcon(_ icon: MenuBarIconStyle, title: String) -> Bool {
        icon != .hidden || title.isEmpty
    }

    /// "70% · −7.5 W", localized through `formatter`.
    public static func menuBarTitle(
        for s: BatterySnapshot?, style: MenuBarStyle, formatter: BatteryFormatter
    ) -> String {
        guard let s else { return "" }
        let percent = s.chargePercent.map { formatter.percent($0) }
        let power = s.batteryPowerWatts.map { formatter.watts($0, signed: true) }
        let parts: [String?] =
            switch style {
            case .percent: [percent]
            case .power: [power]
            case .percentAndPower: [percent, power]
            case .iconOnly: []
            }
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// Level colors used by the app: green above 20 % or while charging, then orange, then red.
    public enum LevelTier: Sendable, Equatable {
        case normal, low, critical
    }

    public static func levelTier(for s: BatterySnapshot) -> LevelTier {
        guard let percent = s.chargePercent, s.chargeState != .charging, percent <= 20 else { return .normal }
        return percent > 10 ? .low : .critical
    }
}

/// One flattened raw IORegistry value, e.g. `AppleSmartBattery.BatteryData.DesignCapacity`.
public struct RawEntry: Sendable, Equatable, Identifiable {
    public var path: String
    public var value: String
    public var id: String { path }

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
                entries.append(RawEntry(path: path, value: value.description))
            }
        }
        visit(.dictionary(dictionary), path: prefix)
        return entries
    }
}

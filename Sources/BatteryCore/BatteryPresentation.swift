import Foundation

/// What the menu bar shows next to the battery icon.
public enum MenuBarStyle: String, Sendable, CaseIterable, Codable {
    case percent
    case power
    case percentAndPower
    case iconOnly

    public var title: String {
        switch self {
        case .percent: "Percentage"
        case .power: "Battery power"
        case .percentAndPower: "Percentage and power"
        case .iconOnly: "Icon only"
        }
    }

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

    public var title: String {
        switch self {
        case .standard: "Standard"
        case .large: "Large"
        case .hidden: "Hidden"
        }
    }
}

/// Short, display-ready strings for the app's menu bar and popover.
///
/// Kept in BatteryCore (rather than the SwiftUI target) so it is tested on Linux.
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

    public static func menuBarTitle(for s: BatterySnapshot?, style: MenuBarStyle) -> String {
        guard let s else { return "" }
        let percent = s.chargePercent.map(percentText)
        let power = s.batteryPowerWatts.map(powerText)
        let parts: [String?] =
            switch style {
            case .percent: [percent]
            case .power: [power]
            case .percentAndPower: [percent, power]
            case .iconOnly: []
            }
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// `78.4` → "78%".
    public static func percentText(_ percent: Double) -> String {
        "\(BatteryReport.fixed(percent, 0))%"
    }

    /// `31.25` → "+31.3 W", `-7.45` → "−7.5 W" (typographic minus).
    public static func powerText(_ watts: Double) -> String {
        BatteryReport.signed(watts, 1).replacingOccurrences(of: "-", with: "−") + " W"
    }

    public static func stateTitle(for s: BatterySnapshot) -> String {
        switch s.chargeState {
        case .charging: "Charging"
        case .discharging: "On battery"
        case .charged: "Fully charged"
        case .notCharging: s.isOptimizedChargingEngaged == true ? "Charging on hold" : "Not charging"
        case .unknown: "Unknown"
        }
    }

    /// "5 h 42 min left", "Full in 1 h 17 min", or "≈"-prefixed when derived by the app.
    public static func timeText(for s: BatterySnapshot) -> String? {
        if s.isTimeRemainingCalculating { return "Calculating time…" }
        return switch s.chargeState {
        case .discharging:
            BatteryReport.timeRemaining(os: s.timeToEmptyMinutes, derived: s.estimatedTimeToEmptyMinutes)
                .map { "\($0) left" }
        case .charging:
            BatteryReport.timeRemaining(os: s.timeToFullMinutes, derived: s.estimatedTimeToFullMinutes)
                .map { "Full in \($0)" }
        case .charged, .notCharging, .unknown:
            nil
        }
    }
}

extension BatteryPresentation {
    /// The handful of readings shown in the menu-bar popover.
    public static func summaryLines(for s: BatterySnapshot) -> [BatteryReport.Line] {
        var lines: [BatteryReport.Line] = []
        func add(_ label: String, _ value: String?) {
            if let value { lines.append(BatteryReport.Line(label: label, value: value)) }
        }
        add("Battery power", s.batteryPowerWatts.map(powerText))
        if let health = s.healthPercent {
            add("Health", [percentText(health), s.healthCondition].compactMap { $0 }.joined(separator: " · "))
        } else {
            add("Condition", s.healthCondition)
        }
        if let cycles = s.cycleCount {
            add("Cycles", s.designCycleCount.map { "\(cycles) of \($0)" } ?? String(cycles))
        }
        add("Temperature", s.temperatureCelsius.map { "\(BatteryReport.fixed($0, 1)) °C" })
        if let adapter = s.adapter {
            add("Adapter", adapter.watts.map { "\($0) W" } ?? adapter.name ?? "Connected")
        }
        if s.isExternalPowerConnected == true, let input = s.systemPowerInWatts, input > 0 {
            add("System input", "\(BatteryReport.fixed(input, 1)) W")
        }
        add("System load", s.systemLoadWatts.map { "\(BatteryReport.fixed($0, 1)) W" })
        return lines
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

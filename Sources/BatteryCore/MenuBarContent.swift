import Foundation

/// The parts the menu bar item can show, in the order they appear.
public enum MenuBarItem: String, Sendable, CaseIterable, Codable {
    case icon, charge, power, temperature
}

/// What the menu bar item shows: any combination of the battery icon, the charge, the battery
/// power and the battery temperature, always in that order ("icon 70% · −7.5 W · 31 °C").
///
/// At least one part shows. With everything off, or while the chosen text has no value yet, the
/// icon shows, so the item never turns into an empty space that can't be clicked.
public struct MenuBarContent: Sendable, Equatable, Hashable {
    public var showsIcon: Bool
    public var showsCharge: Bool
    public var showsPower: Bool
    public var showsTemperature: Bool

    /// The defaults for a new install: the icon and the charge.
    public init(
        showsIcon: Bool = true, showsCharge: Bool = true, showsPower: Bool = false, showsTemperature: Bool = false
    ) {
        self.showsIcon = showsIcon
        self.showsCharge = showsCharge
        self.showsPower = showsPower
        self.showsTemperature = showsTemperature
    }

    public init(items: Set<MenuBarItem>) {
        self.init(
            showsIcon: items.contains(.icon), showsCharge: items.contains(.charge),
            showsPower: items.contains(.power), showsTemperature: items.contains(.temperature))
    }

    public static let `default` = MenuBarContent()

    /// Between the text parts.
    public static let separator = " · "

    /// Whether `item` is turned on, before the fallback to the icon.
    public func isOn(_ item: MenuBarItem) -> Bool {
        switch item {
        case .icon: showsIcon
        case .charge: showsCharge
        case .power: showsPower
        case .temperature: showsTemperature
        }
    }

    /// The parts that show, in order: the icon alone when everything is off.
    public var items: [MenuBarItem] {
        let chosen = MenuBarItem.allCases.filter(isOn)
        return chosen.isEmpty ? [.icon] : chosen
    }

    /// The same choice with the fallback applied, as Settings stores it.
    public var normalized: MenuBarContent {
        MenuBarContent(items: Set(items))
    }

    /// `item` is the only one turned on, so Settings keeps it from being turned off.
    public func isOnlyItem(_ item: MenuBarItem) -> Bool {
        MenuBarItem.allCases.filter(isOn) == [item]
    }

    /// The text parts for `s`, joined by ``separator``: "70% · −7.5 W · 31 °C". A part without a
    /// value (a Mac that reports no temperature) is left out; empty before the first reading.
    public func title(for s: BatterySnapshot?, formatter: BatteryFormatter) -> String {
        guard let s else { return "" }
        let parts: [String?] = items.map { item in
            switch item {
            case .icon: nil
            case .charge: s.chargePercent.map { formatter.percent($0) }
            case .power: s.batteryPowerWatts.map { formatter.watts($0, signed: true) }
            // Whole degrees: the battery warms slowly, and tenths would only flicker.
            case .temperature: s.temperatureCelsius.map { formatter.celsius($0, fractionDigits: 0) }
            }
        }
        return parts.compactMap { $0 }.joined(separator: Self.separator)
    }

    /// The icon shows when chosen, and in place of a title that has nothing to show yet.
    public func showsIcon(title: String) -> Bool {
        items.contains(.icon) || title.isEmpty
    }

    /// How often the menu bar asks for fresh readings. Battery power changes without an OS
    /// notification, so it is polled gently while shown; the charge and the temperature move
    /// slowly enough for the OS's own updates.
    public var liveRefreshInterval: Duration? {
        items.contains(.power) ? .seconds(10) : nil
    }

    /// The menu bar choices before 0.4 were one style (`percent`, `power`, `percentAndPower` or
    /// `iconOnly`) and an icon style (`standard`, `large` or `hidden`). `nil` when neither was
    /// ever stored; unknown values count as the old defaults.
    public static func migrated(legacyStyle: String?, legacyIcon: String?) -> MenuBarContent? {
        guard legacyStyle != nil || legacyIcon != nil else { return nil }
        var content = MenuBarContent(showsIcon: legacyIcon != "hidden", showsCharge: true)
        switch legacyStyle {
        case "power":
            content.showsCharge = false
            content.showsPower = true
        case "percentAndPower":
            content.showsPower = true
        case "iconOnly":
            content.showsCharge = false
        default:
            break
        }
        // An icon-only item with the icon hidden showed the icon anyway.
        return content.normalized
    }
}

/// How the battery icon in the menu bar looks. All but ``symbol`` are drawn to the exact level
/// (``BatteryIconLayout``).
public enum MenuBarIconStyle: String, Sendable, CaseIterable, Codable {
    /// The SF Symbol in five steps, BatteryPulse's icon before 0.4.
    case symbol
    /// Like the battery item of macOS 27: a capsule without an outline, the empty part translucent.
    case modern
    /// The outlined battery macOS showed for years.
    case classic
    /// The modern capsule with the charge number inside.
    case percentageInside
    /// A small circular gauge.
    case ring

    public static let `default` = MenuBarIconStyle.modern

    /// Drawn with shapes rather than an SF Symbol.
    public var isDrawn: Bool { self != .symbol }
}

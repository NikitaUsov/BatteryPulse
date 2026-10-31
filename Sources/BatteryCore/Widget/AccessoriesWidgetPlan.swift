import Foundation

/// What a placed Accessories widget is set to show: the widget's configuration intent maps to it
/// one to one. The defaults list every accessory, lowest first, and hide none.
public struct AccessoriesWidgetConfiguration: Sendable, Equatable {
    /// Medium and large only: small always shows the lowest.
    public var mode: AccessoryWidgetMode
    /// Medium and large only: leaves out an accessory whose every part that counts is full.
    public var hidesFullyCharged: Bool

    public init(mode: AccessoryWidgetMode = .all, hidesFullyCharged: Bool = false) {
        self.mode = mode
        self.hidesFullyCharged = hidesFullyCharged
    }
}

/// What one timeline entry of the Accessories widget shows, decided in BatteryCore so it is tested
/// on Linux; the widget only draws it.
///
/// The accessories come lowest first, by ``AccessoryBattery/level`` (which leaves out the case and
/// the parts that are out of reach), so the lowest one is the first; when it goes away, the next
/// lowest is. Earbuds show each part, as the app does. A row carries no accessory identifier:
/// ``AccessoryBattery/id`` can be brute-forced back to a Bluetooth address, so it never reaches the
/// widget's views, its configuration or its logs.
public enum AccessoriesWidgetPlan: Sendable, Equatable {
    case accessories(AccessoriesWidgetLayout)
    case empty(AccessoriesWidgetEmptyReason)

    /// The most accessories a size lists; small shows one, the lowest.
    static func rowSlots(_ size: WidgetSize) -> Int {
        switch size {
        case .small: 1
        case .medium: 4
        case .large, .extraLarge, .extraLargePortrait: 8
        }
    }

    /// The plan for `entry` of a timeline whose read at `readAt` found `accessories`; `nil` means
    /// this macOS publishes no accessory batteries, which shows as none connected. Clock times are
    /// in `formatter`'s locale and `timeZone`.
    public static func make(
        size: WidgetSize, configuration: AccessoriesWidgetConfiguration, accessories: [AccessoryBattery]?,
        readAt: Date, entry: WidgetTimelinePlan.Entry, formatter: BatteryFormatter, timeZone: TimeZone
    ) -> AccessoriesWidgetPlan {
        guard let accessories, !accessories.isEmpty else { return .empty(.noAccessories) }
        // Small has no room for the choices, so its edit sheet doesn't offer them.
        let lowestOnly = size == .small || configuration.mode == .lowest
        let hides = size != .small && configuration.hidesFullyCharged
        let shown = hides ? accessories.filter { !$0.isFullyCharged } : accessories
        guard !shown.isEmpty else { return .empty(.allFullyCharged) }
        let rows = sortedLowestFirst(shown).map { AccessoryWidgetRow($0, formatter: formatter) }
        let updated =
            entry.isStale
            ? readAt.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened, locale: formatter.locale, timeZone: timeZone))
            : nil
        return .accessories(
            AccessoriesWidgetLayout(
                rows: Array(rows.prefix(lowestOnly ? 1 : rowSlots(size))), showsLowest: lowestOnly, updated: updated))
    }

    /// Lowest ``AccessoryBattery/level`` first; an accessory without one (only a case, or every
    /// part out of reach) last. Equal ones keep the reading's order.
    static func sortedLowestFirst(_ accessories: [AccessoryBattery]) -> [AccessoryBattery] {
        accessories.enumerated()
            .sorted { a, b in
                let (left, right) = (a.element.level?.percent ?? .max, b.element.level?.percent ?? .max)
                return left != right ? left < right : a.offset < b.offset
            }
            .map(\.element)
    }

    /// Every state opens the Accessories page, which lists the accessories or says how to connect
    /// one.
    public var route: WidgetRoute {
        WidgetRoute(widgetPage: .accessories)
    }
}

/// Why the Accessories widget shows a message instead of accessories: one line and a symbol.
public enum AccessoriesWidgetEmptyReason: Sendable, Equatable, CaseIterable {
    /// None connected, or this macOS doesn't publish them ("No accessories with batteries
    /// connected").
    case noAccessories
    /// Hide fully charged left none out ("All accessories are fully charged").
    case allFullyCharged
}

/// The Accessories widget's content for one entry.
public struct AccessoriesWidgetLayout: Sendable, Equatable {
    /// Lowest first: the lowest alone when ``showsLowest``.
    public var rows: [AccessoryWidgetRow]
    /// The lowest accessory drawn large: always in small, and with Lowest only.
    public var showsLowest: Bool
    /// The reading's time ("Updated %@") once it is old: the timeline's stale entry.
    public var updated: String?
}

/// One accessory as the widget shows it: pre-formatted, with no identifier.
public struct AccessoryWidgetRow: Sendable, Equatable {
    public var name: AccessoryWidgetName
    /// ``AccessoryBattery/symbolName``: the kind's, or earbuds for headphones with parts.
    public var symbolName: String
    /// The charge the accessory is sorted by, which the lowest one shows large.
    public var level: AccessoryWidgetCharge
    /// In role order; a single battery is one part, shown without a part symbol.
    public var parts: [AccessoryWidgetPart]
    /// ``AccessoryBattery/hasParts``: earbuds and their case.
    public var hasParts: Bool

    init(_ accessory: AccessoryBattery, formatter: BatteryFormatter) {
        name = accessory.name.isEmpty ? .kind(accessory.kind) : .reported(accessory.name)
        symbolName = accessory.symbolName
        hasParts = accessory.hasParts
        parts = accessory.parts.map { AccessoryWidgetPart(role: $0.role, charge: AccessoryWidgetCharge($0, formatter)) }
        // The level leaves out the case and the parts out of reach; without one, the lowest part,
        // as last reported.
        if let level = accessory.level {
            // The level reads as charging when no part drains; it charges when a part does, and is
            // otherwise on power.
            let charges =
                level.isCharging && accessory.parts.contains { $0.isCharging && !$0.isOffline && $0.role != .case }
            self.level = AccessoryWidgetCharge(
                percent: level.percent, isCharging: charges, isOffline: false,
                isOnExternalPower: level.isCharging && !charges, formatter: formatter)
        } else {
            let lowest = accessory.parts.min { $0.percent < $1.percent }
            self.level =
                lowest.map { AccessoryWidgetCharge($0, formatter) }
                ?? AccessoryWidgetCharge(
                    percent: 0, isCharging: false, isOffline: true, isOnExternalPower: false, formatter: formatter)
        }
    }
}

/// An accessory's name: as it reports it, or, when it reports none, its kind's name, which the
/// widget words as the app does ("Keyboard").
public enum AccessoryWidgetName: Sendable, Equatable {
    case reported(String)
    case kind(AccessoryKind)
}

/// One part of an accessory: the only battery of a keyboard, or a bud or the case of earbuds.
public struct AccessoryWidgetPart: Sendable, Equatable {
    public var role: AccessoryPartRole
    public var charge: AccessoryWidgetCharge
}

/// A charge, pre-formatted, with the state the app names beside it.
public struct AccessoryWidgetCharge: Sendable, Equatable {
    public var percent: Int
    public var text: String
    public var isCharging: Bool
    /// Out of reach: ``text`` is the last charge reported.
    public var isOffline: Bool
    /// On its cable or in its case, not charging.
    public var isOnExternalPower: Bool
    /// The app's level tiers: low at 20 % and critical at 10 % while not charging.
    public var tier: BatteryPresentation.LevelTier

    init(percent: Int, isCharging: Bool, isOffline: Bool, isOnExternalPower: Bool, formatter: BatteryFormatter) {
        self.percent = percent
        self.text = formatter.percent(Double(percent))
        self.isCharging = isCharging
        self.isOffline = isOffline
        self.isOnExternalPower = isOnExternalPower
        self.tier = BatteryPresentation.levelTier(percent: Double(percent), isCharging: isCharging)
    }

    init(_ part: AccessoryPart, _ formatter: BatteryFormatter) {
        self.init(
            percent: part.percent, isCharging: part.isCharging, isOffline: part.isOffline,
            isOnExternalPower: part.isOnExternalPower, formatter: formatter)
    }

    /// The symbol beside a low charge, so its colour is never the only signal; none for a charge
    /// out of reach, which is only the last one reported.
    public var cue: WidgetCue? {
        isOffline ? nil : WidgetCue(tier)
    }

    /// The state worth naming, as the app's Accessories page names it; `nil` while it drains.
    public var status: AccessoryWidgetStatus? {
        if isCharging { return .charging }
        if isOffline { return .lastKnownCharge }
        if isOnExternalPower { return .connectedToPower }
        return nil
    }
}

/// The state beside an accessory's charge, in the app's words.
public enum AccessoryWidgetStatus: Sendable, Equatable, CaseIterable {
    case charging, lastKnownCharge, connectedToPower
}

extension AccessoryBattery {
    /// Every part that counts (not the case, not out of reach) is full, and there is one. The
    /// Accessories widget's Hide fully charged leaves such an accessory out.
    var isFullyCharged: Bool {
        let counting = parts.filter { !$0.isOffline && $0.role != .case }
        return !counting.isEmpty && counting.allSatisfy { $0.percent >= 100 }
    }
}

extension WidgetAccessibility {
    /// Every element of the Accessories widget's `plan`, in the order it shows them: one per
    /// accessory (the lowest one's included), then the reading's time.
    static func elements(_ plan: AccessoriesWidgetPlan) -> [WidgetSpokenLabel] {
        switch plan {
        case .empty(let reason):
            return [reason.spokenLabel]
        case .accessories(let layout):
            var elements = layout.rows.map(\.spokenLabel)
            if let updated = layout.updated { elements.append(.phrases([.key("Updated %@", [.verbatim(updated)])])) }
            return elements
        }
    }
}

extension AccessoryWidgetRow {
    /// "Magic Keyboard, 76 %"; earbuds name each part: "AirPods Pro, Left, 64 %, Right, 61 %,
    /// Case, 90 %, charging".
    public var spokenLabel: WidgetSpokenLabel {
        var phrases: [WidgetPhrase] = [name.phrase]
        for part in parts {
            if hasParts { phrases.append(.key(part.role.labelKey)) }
            phrases += part.charge.phrases
        }
        return .phrases(phrases)
    }
}

extension AccessoryWidgetCharge {
    /// The charge and its state: "45 %, charging" (the menu bar panel's words), or the charge and
    /// the state's own words.
    var phrases: [WidgetPhrase] {
        switch status {
        case .charging: [.key("%@, charging", [.verbatim(text)])]
        case .lastKnownCharge, .connectedToPower: [.verbatim(text), status?.phrase].compactMap { $0 }
        case nil: [.verbatim(text)]
        }
    }
}

extension AccessoriesWidgetEmptyReason {
    /// The message the widget shows; its symbol is hidden.
    public var spokenLabel: WidgetSpokenLabel {
        .phrases([.key(messageKey)])
    }

    var messageKey: String {
        switch self {
        case .noAccessories: "No accessories with batteries connected"
        case .allFullyCharged: "All accessories are fully charged"
        }
    }
}

// The catalog keys of the words the Accessories widget shows or VoiceOver reads, the same keys
// the app uses for them (a macOS test compares them with the widget's).

extension AccessoryWidgetName {
    var phrase: WidgetPhrase {
        switch self {
        case .reported(let name): .verbatim(name)
        case .kind(let kind): .key(kind.titleKey)
        }
    }
}

extension AccessoryKind {
    /// The app's name for the kind, an accessory's name when it reports none.
    var titleKey: String {
        switch self {
        case .keyboard: "Keyboard"
        case .mouse: "Mouse"
        case .trackpad: "Trackpad"
        case .headphones: "Headphones"
        case .speaker: "Speaker"
        case .gameController: "Game Controller"
        case .hearingAid: "Hearing Aid"
        case .other: "Accessory"
        }
    }
}

extension AccessoryPartRole {
    /// The app's name for a part of an accessory with parts. A combined part next to a case is
    /// both earbuds.
    var labelKey: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .case: "Case"
        case .combined: "Earbuds"
        case .single, .other: "Battery"
        }
    }
}

extension AccessoryWidgetStatus {
    var phrase: WidgetPhrase {
        switch self {
        case .charging: .key("Charging")
        case .lastKnownCharge: .key("Last known charge")
        case .connectedToPower: .key("Connected to power")
        }
    }
}

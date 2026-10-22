import Foundation

/// What a placed Battery widget is set to show: the widget's configuration intent maps to it one
/// to one. The defaults are 0.6.x's widget, which every widget placed before 0.7 gets.
public struct BatteryWidgetConfiguration: Sendable, Equatable {
    public var layout: WidgetLayoutMode
    public var main: BatteryWidgetMain
    public var visual: BatteryWidgetVisual
    public var statusLines: [WidgetStatusLine]
    /// Custom's details, in the chosen order; an empty list means no details.
    public var details: [BatteryWidgetField]
    public var time: WidgetTimeStyle
    public var colors: WidgetColorStyle
    public var updateTime: WidgetUpdateTimeStyle

    public init(
        layout: WidgetLayoutMode = .automatic, main: BatteryWidgetMain = .charge, visual: BatteryWidgetVisual = .symbol,
        statusLines: [WidgetStatusLine] = [.state, .time], details: [BatteryWidgetField] = [],
        time: WidgetTimeStyle = .clockTime, colors: WidgetColorStyle = .levelColors,
        updateTime: WidgetUpdateTimeStyle = .whenOld
    ) {
        self.layout = layout
        self.main = main
        self.visual = visual
        self.statusLines = statusLines
        self.details = details
        self.time = time
        self.colors = colors
        self.updateTime = updateTime
    }
}

/// What one timeline entry of the Battery widget shows, decided in BatteryCore so it is tested on
/// Linux; the widget only draws it.
///
/// Automatic's meaning per size is frozen once shipped: small and medium are 0.6.1's widget field
/// for field, apart from the intended changes (an end tomorrow, the attention row, the reading's
/// time once it is old, and a symbol beside a tier that isn't normal).
public enum WidgetLayoutPlan: Sendable, Equatable {
    case battery(BatteryWidgetLayout)
    case empty(WidgetEmptyReason)

    /// The details Automatic shows in each size, in order.
    public static func automatic(_ size: WidgetSize) -> [BatteryWidgetField] {
        switch size {
        case .small: []
        case .medium: [.maximumCapacity, .cycleCount, .temperature]
        case .large:
            [
                .maximumCapacity, .cycleCount, .temperature, .adapter, .systemLoad, .batteryPower, .lowPowerMode,
                .remainingCapacity,
            ]
        // The Battery panel's, then the Power panel's.
        case .extraLarge, .extraLargePortrait:
            [
                .maximumCapacity, .cycleCount, .remainingCapacity, .adapter, .batteryPower, .systemLoad, .temperature,
                .lowPowerMode,
            ]
        }
    }

    /// The most details a size shows, the attention row included. Small has one, which takes the
    /// time line's place.
    public static func detailSlots(_ size: WidgetSize) -> Int {
        switch size {
        case .small: 1
        case .medium: 4
        case .large: 8
        case .extraLarge, .extraLargePortrait: 12
        }
    }

    /// The most lines under the main value. Small and medium have 0.6.1's two.
    public static func lineSlots(_ size: WidgetSize) -> Int {
        switch size {
        case .small, .medium: 2
        case .large, .extraLarge, .extraLargePortrait: 3
        }
    }

    /// The plan for `entry` of a timeline made for `snapshot`; `nil` means the widget read no
    /// battery. Clock times are in `formatter`'s locale and `timeZone`.
    public static func make(
        size: WidgetSize, configuration c: BatteryWidgetConfiguration, snapshot: BatterySnapshot?,
        entry: WidgetTimelinePlan.Entry, formatter: BatteryFormatter, timeZone: TimeZone
    ) -> WidgetLayoutPlan {
        guard let snapshot else { return .empty(.noBattery) }
        guard let percent = snapshot.chargePercent else { return .empty(.noInformation) }
        let time =
            entry.showsEstimate
            ? WidgetTimeText(
                snapshot: snapshot, style: c.time, at: entry.date, locale: formatter.locale, timeZone: timeZone)
            : nil
        let main =
            WidgetMainValue(c.main, snapshot: snapshot, formatter: formatter)
            ?? WidgetMainValue(
                charge: percent, snapshot: snapshot, formatter: formatter)
        let attention = WidgetAttention(snapshot)

        // The details: in order, each once, without the main value, a status line's duplicate,
        // the condition the attention row already raises, or a value the reading lacks.
        let fields = c.layout == .automatic ? automatic(size) : c.details
        var seen: Set<BatteryWidgetField> = []
        if let field = main.kind.field { seen.insert(field) }
        if c.statusLines.contains(.state) { seen.insert(.state) }
        if c.statusLines.contains(.time) { seen.insert(.time) }
        if case .condition = attention { seen.insert(.condition) }
        let rows = fields.compactMap { field -> WidgetRow? in
            guard seen.insert(field).inserted else { return nil }
            return WidgetRow(field, snapshot: snapshot, time: time, formatter: formatter)
        }

        let slots = detailSlots(size)
        let shownRows: [WidgetRow] =
            if size == .small {
                Array(rows.prefix(slots))
            } else {
                Array(rows.prefix(attention == nil ? slots : slots - 1))
            }
        // Battery power is stale between reloads, so it always comes with the reading's time.
        let showsUpdate =
            c.updateTime == .always || entry.isStale || main.kind == .batteryPower
            || shownRows.contains { $0.field == .batteryPower }

        // The lines: the chosen status lines, then what takes the last one's place when there is
        // no room: small's detail, the reading's time, and small's attention row, which comes last.
        var lines: [WidgetLine] = []
        for line in uniqued(c.statusLines) {
            switch line {
            case .state: lines.append(.state(WidgetStateWord(snapshot)))
            case .time: if let time { lines.append(.time(time)) }
            }
        }
        var extras: [WidgetLine] = []
        if size == .small, let row = shownRows.first { extras.append(.detail(row)) }
        if showsUpdate {
            let clock = snapshot.timestamp.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened, locale: formatter.locale, timeZone: timeZone))
            extras.append(.updated(clock))
        }
        if size == .small, let attention { extras.append(.attention(attention)) }
        let lineSlots = lineSlots(size)
        let keptExtras = extras.suffix(lineSlots)
        lines = Array(lines.prefix(lineSlots - keptExtras.count)) + keptExtras

        var details: [WidgetDetail] = []
        if size != .small {
            details = shownRows.map(WidgetDetail.row)
            if let attention { details.append(.attention(attention)) }
        }

        return .battery(
            BatteryWidgetLayout(
                visual: c.visual, level: WidgetLevel(percent: percent, snapshot: snapshot), main: main, lines: lines,
                details: details, tinted: c.colors == .levelColors))
    }

    /// The page a click opens: the one about the main value, or the one that fixes an empty state.
    public var route: WidgetRoute {
        let page: PageID =
            switch self {
            case .empty: .overview
            case .battery(let layout):
                switch layout.main.kind {
                case .charge: .overview
                case .maximumCapacity: .health
                case .temperature, .batteryPower: .power
                }
            }
        return WidgetRoute(widgetPage: page)
    }

    private static func uniqued<T: Hashable>(_ items: [T]) -> [T] {
        var seen: Set<T> = []
        return items.filter { seen.insert($0).inserted }
    }
}

/// Why the widget shows a message instead of a battery: one line and a symbol, and a click opens
/// the page that helps.
public enum WidgetEmptyReason: Sendable, Equatable, CaseIterable {
    /// The widget read no battery: a desktop Mac ("This Mac has no internal battery.").
    case noBattery
    /// A battery without a charge level ("No battery information").
    case noInformation
}

/// The Battery widget's content for one entry.
public struct BatteryWidgetLayout: Sendable, Equatable {
    public var visual: BatteryWidgetVisual
    /// The charge, which the level symbol, the ring and the drawn battery show.
    public var level: WidgetLevel
    public var main: WidgetMainValue
    /// Under the main value, in order.
    public var lines: [WidgetLine]
    /// In order; the attention row, if any, is last. Small has none: its detail and attention row
    /// are lines.
    public var details: [WidgetDetail]
    /// Level colours on; tiers still carry their ``WidgetCue`` when off.
    public var tinted: Bool
}

/// The charge, as the level symbol, a ring or the drawn battery shows it.
public struct WidgetLevel: Sendable, Equatable {
    public var percent: Double
    public var isCharging: Bool
    /// ``BatteryPresentation/symbolName(for:)``.
    public var symbolName: String
    public var tier: BatteryPresentation.LevelTier

    public init(percent: Double, snapshot: BatterySnapshot) {
        self.percent = percent
        self.isCharging = snapshot.chargeState == .charging
        self.symbolName = BatteryPresentation.symbolName(for: snapshot)
        self.tier = BatteryPresentation.levelTier(for: snapshot)
    }

    public var cue: WidgetCue? { WidgetCue(tier) }
}

/// The value the widget shows large, pre-formatted.
public struct WidgetMainValue: Sendable, Equatable {
    /// The value shown: the chosen one, or the charge when the reading lacks it.
    public var kind: BatteryWidgetMain
    public var text: String
    /// For the numeric content transition.
    public var number: Double
    /// Maximum capacity warns as in the app; the charge's tier is the level's.
    public var tier: BatteryPresentation.LevelTier

    /// The charge's symbol says its tier (``WidgetLevel/cue``); another value carries its own.
    public var cue: WidgetCue? { kind == .charge ? nil : WidgetCue(tier) }

    init(charge percent: Double, snapshot: BatterySnapshot, formatter: BatteryFormatter) {
        kind = .charge
        text = formatter.percent(percent)
        number = percent
        tier = BatteryPresentation.levelTier(for: snapshot)
    }

    init?(_ kind: BatteryWidgetMain, snapshot s: BatterySnapshot, formatter f: BatteryFormatter) {
        switch kind {
        case .charge:
            guard let percent = s.chargePercent else { return nil }
            (text, number, tier) = (f.percent(percent), percent, BatteryPresentation.levelTier(for: s))
        case .maximumCapacity:
            guard let health = s.healthPercent else { return nil }
            (text, number, tier) = (f.percent(health), health, BatteryPresentation.healthTier(for: s))
        case .temperature:
            guard let temperature = s.temperatureCelsius else { return nil }
            (text, number, tier) = (f.celsius(temperature), temperature, .normal)
        case .batteryPower:
            guard let watts = s.batteryPowerWatts else { return nil }
            (text, number, tier) = (f.watts(watts, signed: true), watts, .normal)
        }
        self.kind = kind
    }
}

extension BatteryWidgetMain {
    /// The detail that shows the same value.
    var field: BatteryWidgetField? {
        switch self {
        case .charge: nil
        case .maximumCapacity: .maximumCapacity
        case .temperature: .temperature
        case .batteryPower: .batteryPower
        }
    }
}

/// A line under the main value.
public enum WidgetLine: Sendable, Equatable {
    case state(WidgetStateWord)
    case time(WidgetTimeText)
    /// "Updated %@": the reading's own time.
    case updated(String)
    /// Small's one detail, in the time line's place.
    case detail(WidgetRow)
    /// Small's attention row, in the time line's place.
    case attention(WidgetAttention)
}

/// A row of the details.
public enum WidgetDetail: Sendable, Equatable {
    case row(WidgetRow)
    case attention(WidgetAttention)
}

import Foundation
import Testing

@testable import BatteryCore

struct WidgetLayoutPlanTests {
    static let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))
    static let start = WidgetRowTests.full.timestamp
    static let fresh = WidgetTimelinePlan.Entry(date: start, showsEstimate: true)
    static let stale = WidgetTimelinePlan.Entry(
        date: start.addingTimeInterval(45 * 60), showsEstimate: false, isStale: true)

    static func layout(
        _ size: WidgetSize, _ configuration: BatteryWidgetConfiguration = BatteryWidgetConfiguration(),
        _ snapshot: BatterySnapshot = WidgetRowTests.full, entry: WidgetTimelinePlan.Entry = fresh
    ) throws -> BatteryWidgetLayout {
        let plan = WidgetLayoutPlan.make(
            size: size, configuration: configuration, snapshot: snapshot, entry: entry, formatter: formatter,
            timeZone: .gmt)
        guard case .battery(let layout) = plan else { throw PlanError.empty(plan) }
        return layout
    }

    enum PlanError: Error {
        case empty(WidgetLayoutPlan)
    }

    static func custom(_ fields: [BatteryWidgetField], main: BatteryWidgetMain = .charge) -> BatteryWidgetConfiguration
    {
        BatteryWidgetConfiguration(layout: .custom, main: main, details: fields)
    }

    static let everyField = BatteryWidgetField.allCases.filter { $0 != .state && $0 != .time }

    @Test(arguments: WidgetSize.allCases)
    func everySizeFillsItsSlots(_ size: WidgetSize) throws {
        let layout = try Self.layout(size, Self.custom(Self.everyField))
        if size == .small {
            #expect(layout.details.isEmpty)
            #expect(layout.lines.count == 2)
            #expect(layout.lines.last.map { if case .detail = $0 { true } else { false } } == true)
        } else {
            let shown = layout.details.count + layout.powerDetails.count
            #expect(shown == min(WidgetLayoutPlan.detailSlots(size), Self.everyField.count))
        }
        let panels = size == .extraLarge || size == .extraLargePortrait
        #expect(layout.powerDetails.isEmpty == !panels)
        #expect(layout.lines.count <= WidgetLayoutPlan.lineSlots(size))
        #expect(WidgetLayoutPlan.automatic(size).count <= WidgetLayoutPlan.detailSlots(size))
    }

    @Test func slotsPerSize() {
        #expect(WidgetSize.allCases.map(WidgetLayoutPlan.detailSlots) == [1, 4, 8, 12, 12])
        #expect(WidgetSize.allCases.map(WidgetLayoutPlan.lineSlots) == [2, 2, 3, 3, 3])
        #expect(WidgetLayoutPlan.automatic(.large).count == 8)
    }

    /// Extra large is two panels, Battery and Power, with up to half the slots each.
    @Test func extraLargeIsTwoPanels() throws {
        let automatic = try Self.layout(.extraLarge)
        #expect(automatic.details.map(\.field) == [.maximumCapacity, .cycleCount, .remainingCapacity])
        #expect(
            automatic.powerDetails.map(\.field) == [.batteryPower, .adapter, .systemLoad, .temperature, .lowPowerMode])
        #expect(automatic.panelHeadings)
        // Automatic's details are its panels', in order.
        #expect(
            WidgetLayoutPlan.automatic(.extraLarge)
                == WidgetLayoutPlan.automaticBatteryPanel + automatic.powerDetails.compactMap(\.field))
        // Custom fills the Battery panel first, then the Power panel, in the chosen order, and its
        // panels have no names: they hold whatever was chosen.
        let custom = try Self.layout(.extraLarge, Self.custom(Self.everyField))
        #expect(custom.details.map(\.field) == Array(Self.everyField.prefix(6)))
        #expect(custom.powerDetails.map(\.field) == Array(Self.everyField.dropFirst(6).prefix(6)))
        #expect(!custom.panelHeadings)
        let few = try Self.layout(.extraLarge, Self.custom([.voltage, .adapter]))
        #expect(few.details.map(\.field) == [.voltage, .adapter])
        #expect(few.powerDetails.isEmpty)
        // The other sizes have one list and no headings.
        for size in [WidgetSize.small, .medium, .large] {
            let layout = try Self.layout(size, Self.custom(Self.everyField))
            #expect(layout.powerDetails.isEmpty && !layout.panelHeadings)
            #expect(try !Self.layout(size).panelHeadings)
        }
    }

    /// In extra large the attention row takes the last slot of its own panel: a condition the
    /// Battery panel's, heat the Power panel's.
    @Test func inExtraLargeTheAttentionRowJoinsItsPanel() throws {
        var s = WidgetRowTests.full
        s.healthCondition = "Service Recommended"
        let condition = try Self.layout(.extraLarge, Self.custom(Self.everyField), s)
        #expect(condition.details.count == 6)
        #expect(condition.details.last == .attention(.condition(.serviceRecommended)))
        // The row it displaces moves on to the Power panel, which stays full.
        let fields = Self.everyField.filter { $0 != .condition }
        #expect(condition.details.dropLast().map(\.field) == Array(fields.prefix(5)))
        #expect(condition.powerDetails.map(\.field) == Array(fields.dropFirst(5).prefix(6)))
        let automatic = try Self.layout(.extraLarge, BatteryWidgetConfiguration(), s)
        #expect(automatic.details.map(\.field) == [.maximumCapacity, .cycleCount, .remainingCapacity, nil])
        #expect(automatic.powerDetails.count == 5)

        s.healthCondition = nil
        s.thermalState = .serious
        let hot = try Self.layout(.extraLarge, Self.custom(Self.everyField), s)
        #expect(hot.details.count == 6)
        #expect(hot.powerDetails.count == 6)
        #expect(hot.powerDetails.last == .attention(.heat(.serious)))
        let hotAutomatic = try Self.layout(.extraLarge, BatteryWidgetConfiguration(), s)
        #expect(hotAutomatic.details.count == 3)
        #expect(
            hotAutomatic.powerDetails.map(\.field) == [
                .batteryPower, .adapter, .systemLoad, .temperature, .lowPowerMode, nil,
            ])
    }

    /// The level carries what the visuals and VoiceOver need beside the main value.
    @Test func theLevelSaysTheChargeWhateverTheMainValue() throws {
        let layout = try Self.layout(.medium, BatteryWidgetConfiguration(main: .temperature))
        #expect(layout.main.kind == .temperature)
        #expect(layout.level.text == "62%")
        #expect(layout.level.state == .charging)
        #expect(layout.level.icon == BatteryIconState(level: 0.62, percent: 62, glyph: .bolt))
        var low = WidgetRowTests.full
        low.chargeState = .discharging
        low.isExternalPowerConnected = false
        low.chargePercent = 8
        low.isLowPowerModeEnabled = true
        // The menu bar would fill it yellow in Low Power Mode; the widget colours it by its tier.
        let lowLayout = try Self.layout(.small, BatteryWidgetConfiguration(), low)
        #expect(lowLayout.level.icon == BatteryIconState(level: 0.08, percent: 8, glyph: .none, tint: .monochrome))
        #expect(lowLayout.level.tier == .critical)
    }

    @Test func orderIsKeptAndDuplicatesAndTheMainValueDropped() throws {
        let layout = try Self.layout(
            .large, Self.custom([.voltage, .temperature, .cycleCount, .voltage, .state, .time], main: .temperature))
        #expect(layout.main.kind == .temperature)
        #expect(layout.details.map(\.field) == [.voltage, .cycleCount])
    }

    @Test func unavailableValuesAreDropped() throws {
        var s = WidgetRowTests.full
        s.temperatureCelsius = nil
        s.cellVoltagesMV = []
        let layout = try Self.layout(.medium, Self.custom([.temperature, .cellBalance, .voltage]), s)
        #expect(layout.details.map(\.field) == [.voltage])
        // Automatic too: a Mac without a pack temperature shows two details in medium, as 0.6.1 did.
        #expect(
            try Self.layout(.medium, BatteryWidgetConfiguration(), s).details.map(\.field) == [
                .maximumCapacity, .cycleCount,
            ])
    }

    @Test func anEmptyCustomListShowsNoDetails() throws {
        #expect(try Self.layout(.large, Self.custom([])).details.isEmpty)
    }

    /// A status line the user didn't choose can be a detail.
    @Test func theStateAsADetailWithoutItsLine() throws {
        var configuration = Self.custom([.state, .time])
        configuration.statusLines = []
        let layout = try Self.layout(.medium, configuration)
        #expect(layout.lines.isEmpty)
        #expect(layout.details.map(\.field) == [.state, .time])
    }

    @Test func theAttentionRowTakesTheLastSlot() throws {
        var s = WidgetRowTests.full
        s.healthCondition = "Service Recommended"
        let medium = try Self.layout(.medium, Self.custom(Self.everyField), s)
        #expect(medium.details.count == 4)
        #expect(medium.details.last == .attention(.condition(.serviceRecommended)))
        // The condition row says the same, so it gives way.
        #expect(!medium.details.dropLast().contains { $0.field == .condition })
        // Automatic medium has room for it after its three details.
        let automatic = try Self.layout(.medium, BatteryWidgetConfiguration(), s)
        #expect(automatic.details.map(\.field) == [.maximumCapacity, .cycleCount, .temperature, nil])
        // Heat comes first in the attention row, so a chosen condition row stays and the condition
        // still shows. Automatic chooses no condition row; its attention row says the condition
        // again once the heat passes.
        s.thermalState = .critical
        let hot = try Self.layout(.large, Self.custom(Self.everyField), s)
        #expect(hot.details.last == .attention(.heat(.critical)))
        #expect(hot.details.contains { $0.field == .condition })
        let hotMedium = try Self.layout(.medium, Self.custom([.condition, .cycleCount]), s)
        #expect(hotMedium.details.map(\.field) == [.condition, .cycleCount, nil])
        let hotAutomatic = try Self.layout(.medium, BatteryWidgetConfiguration(), s)
        #expect(hotAutomatic.details.map(\.field) == [.maximumCapacity, .cycleCount, .temperature, nil])
    }

    /// Small has no detail slot: the attention row takes the time line's place, in Automatic too.
    @Test func inSmallTheAttentionRowReplacesTheTimeLine() throws {
        var s = WidgetRowTests.full
        s.thermalState = .serious
        let layout = try Self.layout(.small, BatteryWidgetConfiguration(), s)
        #expect(layout.lines == [.state(.charging), .attention(.heat(.serious))])
        #expect(layout.details.isEmpty)
    }

    /// Small's one detail takes the time line's place.
    @Test func inSmallTheDetailReplacesTheTimeLine() throws {
        let layout = try Self.layout(.small, Self.custom([.cycleCount, .voltage]))
        #expect(layout.lines == [.state(.charging), .detail(WidgetRow(field: .cycleCount, value: .text("1,312")))])
    }

    @Test func theReadingsTimeTakesTheLastLineOnceOld() throws {
        let clock = Self.start.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, locale: Self.formatter.locale, timeZone: .gmt))
        #expect(try Self.layout(.small, entry: Self.stale).lines == [.state(.charging), .updated(clock)])
        #expect(try Self.layout(.medium, entry: Self.stale).lines == [.state(.charging), .updated(clock)])
        // A fresh entry shows the time; Always shows the reading's time as well.
        let fresh = try Self.layout(.medium)
        #expect(fresh.lines.count == 2)
        #expect(fresh.lines.last.map { if case .time = $0 { true } else { false } } == true)
        var always = BatteryWidgetConfiguration()
        always.updateTime = .always
        #expect(try Self.layout(.medium, always).lines.last == .updated(clock))
        // Large has room for a third line.
        #expect(try Self.layout(.large, always).lines.count == 3)
    }

    /// Battery power is stale between reloads, so it never shows without the reading's time.
    @Test func batteryPowerComesWithTheReadingsTime() throws {
        let main = try Self.layout(.small, BatteryWidgetConfiguration(main: .batteryPower))
        #expect(main.main.text == "+25.0\u{00A0}W")
        #expect(main.lines.contains { if case .updated = $0 { true } else { false } })
        let detail = try Self.layout(.medium, Self.custom([.batteryPower]))
        #expect(detail.lines.contains { if case .updated = $0 { true } else { false } })
        let without = try Self.layout(.medium, Self.custom([.voltage]))
        #expect(!without.lines.contains { if case .updated = $0 { true } else { false } })
    }

    @Test func aMainValueTheReadingLacksFallsBackToTheCharge() throws {
        var s = WidgetRowTests.full
        s.temperatureCelsius = nil
        let layout = try Self.layout(.medium, BatteryWidgetConfiguration(main: .temperature), s)
        #expect(layout.main.kind == .charge)
        #expect(layout.main.text == "62%")
    }

    @Test func aClickOpensTheMainValuesPage() {
        func route(_ main: BatteryWidgetMain) -> PageID? {
            WidgetLayoutPlan.make(
                size: .small, configuration: BatteryWidgetConfiguration(main: main), snapshot: WidgetRowTests.full,
                entry: Self.fresh, formatter: Self.formatter, timeZone: .gmt
            ).route.page
        }
        #expect(route(.charge) == .overview)
        #expect(route(.maximumCapacity) == .health)
        #expect(route(.temperature) == .power)
        #expect(route(.batteryPower) == .power)
        for reason in WidgetEmptyReason.allCases {
            #expect(WidgetLayoutPlan.empty(reason).route.page == .overview)
        }
    }

    // MARK: The non-colour cue

    /// A battery in each tier that isn't normal, and what shows it.
    static var tiers: [(String, BatterySnapshot, BatteryWidgetConfiguration)] {
        var low = WidgetRowTests.full
        low.chargeState = .discharging
        low.chargePercent = 15
        var critical = low
        critical.chargePercent = 5
        var lowHealth = WidgetRowTests.full
        lowHealth.nominalChargeCapacityMAh = 3_500
        var condition = WidgetRowTests.full
        condition.healthCondition = "Check Battery"
        var hot = WidgetRowTests.full
        hot.thermalState = .serious
        return [
            ("low charge", low, BatteryWidgetConfiguration()),
            ("critical charge", critical, BatteryWidgetConfiguration()),
            ("low charge, another main value", low, BatteryWidgetConfiguration(main: .temperature)),
            ("low health, main value", lowHealth, BatteryWidgetConfiguration(main: .maximumCapacity)),
            ("low health, a detail", lowHealth, Self.custom([.maximumCapacity])),
            ("abnormal condition", condition, BatteryWidgetConfiguration()),
            ("abnormal condition, Custom", condition, Self.custom([.voltage])),
            ("high heat", hot, BatteryWidgetConfiguration()),
        ]
    }

    @Test func everyTierThatIsNotNormalHasASymbolInEveryColourStyle() throws {
        for (name, snapshot, configuration) in Self.tiers {
            for colors in WidgetColorStyle.allCases {
                for size in WidgetSize.allCases {
                    var configuration = configuration
                    configuration.colors = colors
                    let layout = try Self.layout(size, configuration, snapshot)
                    #expect(!layout.cues.isEmpty, "\(name), \(colors), \(size)")
                    #expect(layout.tinted == (colors == .levelColors))
                }
            }
        }
    }

    @Test func aNormalBatteryHasNoCue() throws {
        for size in WidgetSize.allCases {
            #expect(try Self.layout(size, Self.custom(Self.everyField)).cues.isEmpty)
        }
    }

    /// The attention row's symbol is tinted by how serious its cause is.
    @Test func attentionTiers() {
        #expect(WidgetAttention.heat(.serious).tier == .low)
        #expect(WidgetAttention.heat(.critical).tier == .critical)
        #expect(WidgetAttention.condition(.serviceRecommended).tier == .low)
        #expect(WidgetAttention.condition(.checkBattery).tier == .critical)
    }

    @Test func cuesFollowTheirTiers() {
        #expect(WidgetCue(.normal) == nil)
        #expect(WidgetCue(.low)?.symbolName == "exclamationmark.circle")
        #expect(WidgetCue(.critical)?.symbolName == "exclamationmark.triangle.fill")
    }
}

extension WidgetDetail {
    var field: BatteryWidgetField? {
        if case .row(let row) = self { row.field } else { nil }
    }
}

extension BatteryWidgetLayout {
    /// Every symbol the plan adds for a tier or a warning.
    var cues: [String] {
        var symbols = [level.cue, main.cue].compactMap { $0?.symbolName }
        for line in lines {
            switch line {
            case .detail(let row): symbols += [row.cue?.symbolName].compactMap { $0 }
            case .attention(let attention): symbols.append(attention.symbolName)
            case .state, .time, .updated: break
            }
        }
        for detail in details + powerDetails {
            switch detail {
            case .row(let row): symbols += [row.cue?.symbolName].compactMap { $0 }
            case .attention(let attention): symbols.append(attention.symbolName)
            }
        }
        return symbols
    }
}

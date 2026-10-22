import Foundation
import Testing

@testable import BatteryCore

/// Automatic in small and medium is v0.6.1's widget, field for field: a widget placed before 0.7
/// keeps its look. Pinned before the configurable widget replaces the view, so this test stays
/// unchanged after that.
struct WidgetAutomaticTests {
    /// v0.6.1's widget as data: what `BatteryWidgetView` drew (`BatteryPulseWidget.swift`, lines
    /// 80-205 at v0.6.1), with every label and phrase as its catalog key.
    struct V061Widget: Equatable {
        struct Row: Equatable {
            var label: String
            var value: String
        }

        var symbol: String
        var symbolTint: BatteryPresentation.LevelTier
        var number: String
        var state: String
        /// The phrase's key with the clock time in place of `%@`.
        var time: String?
        var rows: [Row]

        init(
            _ s: BatterySnapshot, _ size: WidgetSize, entry: WidgetTimelinePlan.Entry, formatter: BatteryFormatter,
            timeZone: TimeZone
        ) throws {
            let percent = try #require(s.chargePercent)
            symbol = BatteryPresentation.symbolName(for: s)
            symbolTint = BatteryPresentation.levelTier(for: s)
            number = formatter.percent(percent)
            state =
                switch s.chargeState {
                case .charging: "Charging"
                case .discharging: "On battery"
                case .charged: "Fully charged"
                case .notCharging: s.isOptimizedChargingEngaged == true ? "Charging on hold" : "Not charging"
                case .unknown: "Unknown"
                }
            func clock(_ minutes: Int) -> String {
                entry.date.addingTimeInterval(Double(minutes) * 60)
                    .formatted(
                        Date.FormatStyle(date: .omitted, time: .shortened, locale: formatter.locale, timeZone: timeZone)
                    )
            }
            time =
                switch (entry.showsEstimate, s.chargeState) {
                case (true, .charging): s.estimatedTimeToFullMinutes.map { "Full at \(clock($0))" }
                case (true, .discharging): s.estimatedTimeToEmptyMinutes.map { "Lasts until about \(clock($0))" }
                default: nil
                }
            rows = []
            guard size == .medium else { return }
            if let health = s.healthPercent {
                rows.append(Row(label: "Maximum capacity", value: formatter.percent(health)))
            }
            if let cycles = s.cycleCount {
                rows.append(Row(label: "Cycle count", value: cycles.formatted(.number.locale(formatter.locale))))
            }
            if let temperature = s.temperatureCelsius {
                rows.append(Row(label: "Temperature", value: formatter.celsius(temperature)))
            }
        }

        /// The plan, read back into 0.6.1's fields; `nil` where it shows something 0.6.1 never did.
        init?(_ plan: WidgetLayoutPlan) {
            guard case .battery(let layout) = plan, layout.tinted, layout.visual == .symbol, layout.main.kind == .charge
            else { return nil }
            symbol = layout.level.symbolName
            symbolTint = layout.level.tier
            number = layout.main.text
            guard case .state(let word) = layout.lines.first else { return nil }
            state = WidgetKeys.state(word)
            switch layout.lines.dropFirst().first {
            case nil: time = nil
            case .time(let text)?:
                guard let phrase = WidgetKeys.time(text) else { return nil }
                time = phrase
            default: return nil
            }
            guard layout.lines.count <= 2 else { return nil }
            rows = []
            for detail in layout.details {
                guard case .row(let row) = detail, case .text(let value) = row.value else { return nil }
                rows.append(Row(label: WidgetKeys.label(row.field), value: value))
            }
        }
    }

    static let cases: [(Locale, TimeZone)] = [
        (Locale(identifier: "en_US"), TimeZone(secondsFromGMT: 0)!),
        (Locale(identifier: "ru_RU"), TimeZone(secondsFromGMT: 3 * 3600)!),
        (Locale(identifier: "en_GB"), TimeZone(secondsFromGMT: -8 * 3600)!),
    ]

    /// The real captures, and a battery without a pack temperature (the sandboxed widget can't
    /// fall back to the SMC's).
    static func snapshots() throws -> [BatterySnapshot] {
        var snapshots = try Fixture.allCases.map { try $0.snapshot() }
        var withoutTemperature = try Fixture.m5OnBatterySMC.snapshot()
        withoutTemperature.temperatureCelsius = nil
        snapshots.append(withoutTemperature)
        return snapshots
    }

    @Test(arguments: [WidgetSize.small, .medium])
    func automaticIsV061sWidget(_ size: WidgetSize) throws {
        let snapshots = try Self.snapshots()
        #expect(snapshots.contains { $0.temperatureCelsius == nil })
        #expect(snapshots.contains { WidgetTimelinePlan.estimateMinutes($0) != nil })
        for (locale, timeZone) in Self.cases {
            let formatter = BatteryFormatter(locale: locale)
            for snapshot in snapshots {
                // A fresh reading: the timeline's first entry, at the reading's time.
                let entry = try #require(WidgetTimelinePlan(snapshot: snapshot, at: snapshot.timestamp).entries.first)
                let plan = WidgetLayoutPlan.make(
                    size: size, configuration: BatteryWidgetConfiguration(), snapshot: snapshot, entry: entry,
                    formatter: formatter, timeZone: timeZone)
                let expected = try V061Widget(snapshot, size, entry: entry, formatter: formatter, timeZone: timeZone)
                #expect(V061Widget(plan) == expected, "\(size) \(locale.identifier) \(snapshot.chargeState)")
                #expect(plan.route == WidgetRoute(page: .overview))
            }
        }
    }

    @Test func automaticsDetailsPerSize() {
        #expect(WidgetLayoutPlan.automatic(.small).isEmpty)
        #expect(WidgetLayoutPlan.automatic(.medium) == [.maximumCapacity, .cycleCount, .temperature])
    }

    /// 0.6.1 drew "No battery information" for any missing reading.
    @Test func withoutAReadingAMessage() {
        let entry = WidgetTimelinePlan.Entry(date: .now, showsEstimate: true)
        for size in [WidgetSize.small, .medium] {
            let plan = WidgetLayoutPlan.make(
                size: size, configuration: BatteryWidgetConfiguration(), snapshot: nil, entry: entry,
                formatter: BatteryFormatter(), timeZone: .gmt)
            #expect(plan == .empty(.noBattery))
            var s = BatterySnapshot(timestamp: .now)
            s.chargePercent = nil
            #expect(
                WidgetLayoutPlan.make(
                    size: size, configuration: BatteryWidgetConfiguration(), snapshot: s, entry: entry,
                    formatter: BatteryFormatter(), timeZone: .gmt) == .empty(.noInformation))
        }
    }
}

/// The catalog keys the widget shows for the plan's words, as the widget maps them.
enum WidgetKeys {
    static func state(_ word: WidgetStateWord) -> String {
        switch word {
        case .charging: "Charging"
        case .onBattery: "On battery"
        case .fullyCharged: "Fully charged"
        case .chargingOnHold: "Charging on hold"
        case .notCharging: "Not charging"
        case .unknown: "Unknown"
        }
    }

    /// The phrase with its clock time; `nil` for the time left, which the widget counts itself.
    static func time(_ text: WidgetTimeText) -> String? {
        guard case .clock(let clock, let tomorrow) = text.form else { return nil }
        let phrase =
            switch (text.direction, tomorrow) {
            case (.full, false): "Full at %@"
            case (.empty, false): "Lasts until about %@"
            case (.full, true): "Full at %@ tomorrow"
            case (.empty, true): "Lasts until %@ tomorrow"
            }
        return phrase.replacingOccurrences(of: "%@", with: clock)
    }

    static func label(_ field: BatteryWidgetField) -> String {
        switch field {
        case .state: "State"
        case .time: "Time"
        case .maximumCapacity: "Maximum capacity"
        case .condition: "Condition"
        case .cycleCount: "Cycle count"
        case .temperature: "Temperature"
        case .adapter: "Adapter"
        case .systemLoad: "System load"
        case .batteryPower: "Battery power"
        case .adapterInput: "Power from adapter"
        case .lowPowerMode: "Low Power Mode"
        case .remainingCapacity: "Remaining capacity"
        case .cycleLifeUsed: "Cycle life used"
        case .cellBalance: "Cell balance"
        case .voltage: "Voltage"
        }
    }
}

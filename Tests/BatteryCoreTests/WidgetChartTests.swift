import Foundation
import Testing

@testable import BatteryCore

/// A widget chart from the feed (``WidgetChart``): its geometry, its axes and labels, its one
/// VoiceOver label in both languages, and the large Battery widget's History chart.
struct WidgetChartTests {
    typealias Language = WidgetTextBudgetTests.Language

    static let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))
    static let utc = TimeZone(identifier: "UTC") ?? .current
    /// 2026-11-05 10:07:30 UTC.
    static let now = WidgetFeedTests.now

    /// A feed written at ``now`` with the day series' last steps (the rest gaps), oldest first.
    static func feed(
        percent: [Int?] = [], plugged: [Bool?] = [], watts: [Int?] = [], temperature: [Int?] = [],
        recordsHistory: Bool = true, daily: WidgetFeed.Daily? = nil
    ) -> WidgetFeed {
        func padded<T>(_ values: [T?]) -> [T?] {
            Array(repeating: nil, count: max(0, 96 - values.count)) + values.suffix(96)
        }
        let day = WidgetFeed.Series(
            start: WidgetFeed.seriesStart(.day, at: now), step: 900, percent: padded(percent),
            batteryWatts10: padded(watts), temperature10: padded(temperature), plugged: padded(plugged))
        return WidgetFeed(
            writtenAt: now, languages: ["en"], recordsHistory: recordsHistory, readsDevices: false,
            day: recordsHistory ? day : nil, week: nil,
            statistics24h: recordsHistory
                ? WidgetFeed.Statistics(
                    averageDrainPercentPerHour: 8.24, timeOnBattery: 5 * 3600 + 1800, chargingSessions: 2)
                : nil, daily: daily)
    }

    static func chart(
        _ series: HistoryWidgetSeries = .charge, _ period: HistoryWidgetPeriod = .day, feed: WidgetFeed,
        formatter: BatteryFormatter = formatter
    ) throws -> WidgetChart {
        try #require(WidgetChart(series, period: period, feed: feed, formatter: formatter, timeZone: utc))
    }

    static func content(_ feed: WidgetFeed?, at date: Date = now) -> WidgetChartContent {
        WidgetChartContent.make(.charge, period: .day, feed: feed, at: date, formatter: formatter, timeZone: utc)
    }

    // MARK: The states

    /// Without a feed, with recording off or with nothing of the series: a message; a feed two
    /// hours old keeps its chart and says so.
    @Test func eachPlaceSaysWhyItHasNoChart() throws {
        #expect(Self.content(nil) == .message(.noFeed))
        #expect(Self.content(Self.feed(percent: [50], recordsHistory: false)) == .message(.recordingOff))
        #expect(Self.content(Self.feed()) == .message(.noHistory))
        let feed = Self.feed(percent: [60, 59])
        let chart = try Self.chart(feed: feed)
        #expect(Self.content(feed, at: Self.now.addingTimeInterval(2 * 3600 - 1)) == .chart(chart, isOutdated: false))
        #expect(Self.content(feed, at: Self.now.addingTimeInterval(2 * 3600)) == .chart(chart, isOutdated: true))
        #expect(
            WidgetAccessibility.elements(.chart(chart, isOutdated: true)) == [
                chart.summary.spokenLabel, .phrases([.key("Open BatteryPulse to update")]),
            ])
        #expect(
            WidgetChart(.temperature, period: .day, feed: feed, formatter: Self.formatter, timeZone: Self.utc) == nil)
        #expect(
            WidgetChart(.cycleCount, period: .day, feed: feed, formatter: Self.formatter, timeZone: Self.utc) == nil)
        #expect(WidgetChart(.charge, period: .week, feed: feed, formatter: Self.formatter, timeZone: Self.utc) == nil)
    }

    // MARK: The geometry

    @Test func gapsSplitTheLineAndPlugsShade() throws {
        let percent: [Int?] = [50, 60, nil, nil, 70, 80, 90, nil, 100]
        let plugged: [Bool?] = [false, false, nil, nil, true, true, true, nil, true]
        let chart = try Self.chart(feed: Self.feed(percent: percent, plugged: plugged))
        #expect(chart.runs.map(\.count) == [2, 3, 1])
        // The charge's axis is its whole range, so y is the charge in hundredths.
        #expect(chart.runs[0].map(\.y) == [0.5, 0.6])
        #expect(chart.runs.last?.first?.y == 1)
        // Each point is in the middle of its step of 96.
        let first = 96 - percent.count
        #expect(chart.runs[0][0].x == (Double(first) + 0.5) / 96)
        #expect(
            chart.pluggedSpans == [
                WidgetChartSpan(start: Double(first + 4) / 96, end: Double(first + 7) / 96),
                WidgetChartSpan(start: Double(first + 8) / 96, end: 1),
            ])
        #expect(chart.zero == nil)
        #expect((chart.bottomLabel, chart.topLabel) == ("0%", "100%"))
        #expect(chart.latest == "100%")
        // The day's clock times: from the series' start to when the app wrote the feed.
        #expect(chart.startLabel == "10:15\u{202F}AM" && chart.endLabel == "10:07\u{202F}AM")
    }

    /// A flat line sits in the middle of an axis a few units tall; battery power's axis keeps its
    /// zero, and the cycle count's line goes in steps.
    @Test func eachSeriesHasItsAxis() throws {
        let flat = try Self.chart(.temperature, feed: Self.feed(temperature: [300, 300, 300]))
        #expect(flat.runs[0].allSatisfy { $0.y == 0.5 })
        #expect((flat.bottomLabel, flat.topLabel) == ("28\u{00A0}°C", "32\u{00A0}°C"))
        #expect(flat.latest == "30.0\u{00A0}°C")

        let power = try Self.chart(.batteryPower, feed: Self.feed(watts: [-84, 120, 255]))
        // −8.4 to 25.5 W: an axis from −10 to 30 W, its zero a quarter of the way up.
        #expect(power.zero == 0.25)
        #expect(power.bottomLabel == "\u{2212}10\u{00A0}W" && power.topLabel == "+30\u{00A0}W")
        #expect(power.latest == "+25.5\u{00A0}W")
        #expect(power.summary.lowest == "\u{2212}8.4\u{00A0}W")

        let daily = WidgetFeed.Daily(
            firstDay: "2026-11-01", capacityToDesign10: [990, nil, 985, 980, 975], cycleCount: [10, nil, 10, 11, 12])
        let cycles = try Self.chart(.cycleCount, feed: Self.feed(daily: daily))
        // Across the missing day, in steps: 10, 10, then up to 11 and 12.
        #expect(cycles.runs.count == 1)
        #expect(cycles.runs[0].map(\.x) == [0.1, 0.5, 0.7, 0.7, 0.9, 0.9])
        #expect(cycles.startLabel == "Nov 1" && cycles.endLabel == "Nov 5")
        #expect(cycles.latest == "12" && cycles.summary.span == .days90)
        // The 90-day series whatever the period.
        let capacity = try Self.chart(.capacityToDesign, .week, feed: Self.feed(daily: daily))
        #expect(capacity.runs[0].count == 4)
        #expect(capacity.latest == "97.5%" && (capacity.bottomLabel, capacity.topLabel) == ("97%", "99%"))
    }

    /// The axis rounds out to whole steps and widens to its least height, half of the room below.
    @Test func axesRoundOut() {
        #expect(HistoryWidgetSeries.rounded(31.2, 33.9, step: 1, minimumSpan: 4) == 31...35)
        #expect(HistoryWidgetSeries.rounded(30, 30, step: 1, minimumSpan: 4) == 28...32)
        #expect(HistoryWidgetSeries.rounded(-3, 41, step: 5, minimumSpan: 10) == -5...45)
        #expect(HistoryWidgetSeries.batteryPower.axis(low: 2, high: 4) == 0...10)
        #expect(HistoryWidgetSeries.charge.axis(low: 40, high: 41) == 0...100)
    }

    /// The week's series, labelled with days.
    @Test func theWeekIsLabelledWithDays() throws {
        let week = try Self.chart(.charge, .week, feed: WidgetFeed.sample(at: Self.now))
        #expect(week.summary.span == .days7)
        #expect(week.startLabel == "Oct 29" && week.endLabel == "Nov 5")
        // The sample's third day is a gap.
        #expect(week.runs.count == 2)
        #expect(!week.pluggedSpans.isEmpty)
    }

    // MARK: VoiceOver

    /// One label per chart, in both languages, with its values and no counted phrase.
    @Test(arguments: Language.allCases)
    func eachChartHasOneLabel(_ language: Language) throws {
        let localize = WidgetAccessibilityTests.localize(language)
        let f = try WidgetTextBudgetTests.formatter(language)
        let feed = WidgetFeed.sample(at: Self.now)
        for series in HistoryWidgetSeries.allCases {
            for period in HistoryWidgetPeriod.allCases {
                let chart = try Self.chart(series, period, feed: feed, formatter: f)
                let label = try #require(chart.summary.spokenLabel.text(localize))
                #expect(label.contains(chart.latest) && label.contains(chart.summary.lowest), "\(label)")
                #expect(label.contains(chart.summary.highest), "\(label)")
                #expect(!label.contains("%@") && label.contains("Lowest") == (language == .english), "\(label)")
                for key in chart.summary.spokenLabel.keys {
                    #expect(try WidgetTextBudgetTests.text(key, .russian)?.isEmpty == false, "\(key)")
                }
            }
        }
        let english = WidgetChartSummary(series: .charge, span: .hours24, lowest: "31%", highest: "100%", latest: "54%")
        #expect(english.spokenLabel.text { $0 } == "Charge, 24 Hours, Lowest 31%, highest 100%, latest 54%")
        for reason in HistoryWidgetEmptyReason.allCases {
            #expect(try WidgetTextBudgetTests.text(reason.messageKey, .russian)?.isEmpty == false)
        }
    }

    // MARK: The large Battery widget

    static func battery(
        _ size: WidgetSize, _ configuration: BatteryWidgetConfiguration = BatteryWidgetConfiguration(),
        _ snapshot: BatterySnapshot = WidgetRowTests.full, feed: WidgetFeed?,
        at date: Date = WidgetRowTests.full.timestamp
    ) throws -> BatteryWidgetLayout {
        let plan = WidgetLayoutPlan.make(
            size: size, configuration: configuration, snapshot: snapshot,
            entry: WidgetTimelinePlan.Entry(date: date, showsEstimate: true), formatter: formatter, timeZone: utc,
            feed: feed)
        guard case .battery(let layout) = plan else { throw PlanError.empty }
        return layout
    }

    enum PlanError: Error { case empty }

    /// Large's History chart takes the last two of Automatic's eight details, with or without a
    /// feed; off, large shows 0.7.0's eight. Small and medium never show it.
    @Test func largeShowsTheChartInPlaceOfTheLastTwoDetails() throws {
        let fields = { (layout: BatteryWidgetLayout) in
            layout.details.compactMap { if case .row(let row) = $0 { row.field } else { nil } }
        }
        let automatic = WidgetLayoutPlan.automatic(.large)
        let sample = WidgetFeed.sample(at: WidgetRowTests.full.timestamp)
        let chart = try Self.battery(.large, feed: sample)
        #expect(fields(chart) == Array(automatic.prefix(6)))
        guard case .chart(let drawn, isOutdated: false) = chart.chart else {
            Issue.record("\(String(describing: chart.chart))")
            return
        }
        #expect(drawn == (try Self.chart(feed: sample)))
        let off = try Self.battery(.large, BatteryWidgetConfiguration(historyChart: false), feed: sample)
        #expect(fields(off) == automatic && off.chart == nil)
        // Without a feed, with recording off, and with an old feed, the chart's place says why.
        #expect(try Self.battery(.large, feed: nil).chart == .message(.noFeed))
        #expect(try fields(Self.battery(.large, feed: nil)) == Array(automatic.prefix(6)))
        var recordingOff = sample
        recordingOff.recordsHistory = false
        #expect(try Self.battery(.large, feed: recordingOff).chart == .message(.recordingOff))
        let later = WidgetRowTests.full.timestamp.addingTimeInterval(3 * 3600)
        #expect(try Self.battery(.large, feed: sample, at: later).chart == .chart(drawn, isOutdated: true))
        for size in [WidgetSize.small, .medium] {
            #expect(try Self.battery(size, feed: sample).chart == nil)
        }
        // The chart reads after the details.
        let elements = WidgetAccessibility.elements(.battery(chart))
        #expect(elements.last == drawn.summary.spokenLabel)
    }

    // MARK: The sample

    /// The gallery's made-up feed is one a reader accepts, and charts every series.
    @Test func theSampleIsAValidFeedWithEverySeries() throws {
        let sample = WidgetFeed.sample(at: Self.now)
        let decoded = try WidgetFeed.decode(try WidgetFeed.encoded(sample), now: Self.now)
        #expect(decoded == sample)
        #expect(try WidgetFeed.encoded(sample).count <= WidgetFeed.largestBytes)
        for series in HistoryWidgetSeries.allCases {
            for period in HistoryWidgetPeriod.allCases {
                #expect(
                    WidgetChart(series, period: period, feed: sample, formatter: Self.formatter, timeZone: Self.utc)
                        != nil)
            }
        }
    }
}

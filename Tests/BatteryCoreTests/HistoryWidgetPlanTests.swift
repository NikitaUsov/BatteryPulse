import Foundation
import Testing

@testable import BatteryCore

/// The History widget: what each family shows from the feed, its states, its VoiceOver elements
/// in both languages, and its timeline.
struct HistoryWidgetPlanTests {
    typealias Language = WidgetTextBudgetTests.Language

    static let formatter = WidgetChartTests.formatter
    static let now = WidgetChartTests.now
    static let fresh = WidgetTimelinePlan.Entry(date: now, showsEstimate: false)

    static func feed(percent: [Int?] = [], recordsHistory: Bool = true) -> WidgetFeed {
        WidgetChartTests.feed(percent: percent, recordsHistory: recordsHistory)
    }

    static func plan(
        _ size: WidgetSize, _ configuration: HistoryWidgetConfiguration = HistoryWidgetConfiguration(),
        feed: WidgetFeed?, at entry: WidgetTimelinePlan.Entry = fresh, formatter: BatteryFormatter = formatter
    ) -> HistoryWidgetPlan {
        HistoryWidgetPlan.make(
            size: size, configuration: configuration, feed: feed, entry: entry, formatter: formatter,
            timeZone: WidgetChartTests.utc)
    }

    static func layout(
        _ size: WidgetSize, _ configuration: HistoryWidgetConfiguration = HistoryWidgetConfiguration(),
        feed: WidgetFeed?, at entry: WidgetTimelinePlan.Entry = fresh
    ) throws -> HistoryWidgetLayout {
        guard case .history(let layout) = plan(size, configuration, feed: feed, at: entry) else {
            throw PlanError.empty
        }
        return layout
    }

    enum PlanError: Error { case empty }

    /// Medium charts the series; large adds the period's figures, unless Statistics is off.
    @Test func eachFamilyShowsItsParts() throws {
        let feed = Self.feed(percent: [80, 79, 78])
        let medium = try Self.layout(.medium, feed: feed)
        #expect(medium.statistics.isEmpty && !medium.isOutdated)
        #expect(medium.chart == (try WidgetChartTests.chart(feed: feed)))
        let large = try Self.layout(.large, feed: feed)
        #expect(large.statistics.map(\.kind) == [.averageDrain, .onBattery, .chargingSessions])
        #expect(
            large.statistics.map(\.value) == [
                .perHour("8.2%"), .text(Self.formatter.duration(minutes: 330)), .text("2"),
            ])
        let off = try Self.layout(.large, HistoryWidgetConfiguration(showsStatistics: false), feed: feed)
        #expect(off.statistics.isEmpty)
        // Without the figures, each "—".
        var none = feed
        none.statistics24h = nil
        #expect(try Self.layout(.large, feed: none).statistics.map(\.value) == Array(repeating: .text("—"), count: 3))
        #expect(Self.plan(.medium, feed: feed).route.url.absoluteString == "batterypulse://page/history")
        #expect(Self.plan(.medium, feed: nil).route.page == .history)
    }

    /// Large's figures are the chart's period's, as the History page's are its own: the last 24
    /// hours' under a 24-hour chart, the last 7 days' under a 7-day chart and under the 90-day
    /// series, whatever their hidden period.
    @Test func theFiguresFollowTheChartsPeriod() throws {
        let feed = WidgetFeed.sample(at: Self.now)
        let day = try #require(feed.statistics24h)
        let week = try #require(feed.statistics7d)
        #expect(day != week)
        func figures(_ series: HistoryWidgetSeries, _ period: HistoryWidgetPeriod) throws -> [HistoryWidgetStatistic] {
            try Self.layout(.large, HistoryWidgetConfiguration(period: period, series: series), feed: feed).statistics
        }
        let dayFigures = HistoryWidgetStatistic.all(day, formatter: Self.formatter)
        let weekFigures = HistoryWidgetStatistic.all(week, formatter: Self.formatter)
        for series in HistoryWidgetSeries.allCases where !series.isDaily {
            #expect(try figures(series, .day) == dayFigures, "\(series)")
            #expect(try figures(series, .week) == weekFigures, "\(series)")
        }
        for series in HistoryWidgetSeries.allCases where series.isDaily {
            #expect(try figures(series, .day) == weekFigures, "\(series)")
            #expect(try figures(series, .week) == weekFigures, "\(series)")
        }
        #expect(
            weekFigures.map(\.value) == [
                .perHour("3.5%"), .text(Self.formatter.duration(minutes: 96 * 60)), .text("5"),
            ])
        // A feed without the week's figures: each "—" under a 7-day chart, the day's still under a
        // 24-hour one.
        var dayOnly = feed
        dayOnly.statistics7d = nil
        let weekLayout = try Self.layout(.large, HistoryWidgetConfiguration(period: .week), feed: dayOnly)
        #expect(weekLayout.statistics.map(\.value) == Array(repeating: .text("—"), count: 3))
        #expect(try Self.layout(.large, feed: dayOnly).statistics == dayFigures)
        // Medium shows none, whatever the period.
        #expect(try Self.layout(.medium, HistoryWidgetConfiguration(period: .week), feed: feed).statistics.isEmpty)
    }

    /// Without a feed, with recording off or with nothing of the series: a message.
    @Test func theStatesWithoutAChart() {
        #expect(Self.plan(.medium, feed: nil) == .empty(.noFeed))
        #expect(Self.plan(.large, feed: Self.feed(percent: [50], recordsHistory: false)) == .empty(.recordingOff))
        #expect(Self.plan(.medium, feed: Self.feed()) == .empty(.noHistory))
        let feed = Self.feed(percent: [50])
        #expect(Self.plan(.medium, HistoryWidgetConfiguration(series: .temperature), feed: feed) == .empty(.noHistory))
        #expect(Self.plan(.medium, HistoryWidgetConfiguration(series: .cycleCount), feed: feed) == .empty(.noHistory))
        // Recording off comes first, whatever the series.
        #expect(
            Self.plan(
                .medium, HistoryWidgetConfiguration(series: .capacityToDesign), feed: Self.feed(recordsHistory: false))
                == .empty(.recordingOff))
    }

    /// A feed two hours old keeps its last data and says "Open BatteryPulse to update".
    @Test func anOldFeedSaysSo() throws {
        let feed = Self.feed(percent: [60, 59])
        let almost = WidgetTimelinePlan.Entry(date: Self.now.addingTimeInterval(2 * 3600 - 1), showsEstimate: false)
        let old = WidgetTimelinePlan.Entry(date: Self.now.addingTimeInterval(2 * 3600), showsEstimate: false)
        #expect(try !Self.layout(.medium, feed: feed, at: almost).isOutdated)
        let outdated = try Self.layout(.medium, feed: feed, at: old)
        #expect(outdated.isOutdated)
        #expect(outdated.chart == (try Self.layout(.medium, feed: feed)).chart)
        #expect(
            WidgetAccessibility.elements(.history(outdated)).last == .phrases([.key("Open BatteryPulse to update")]))
    }

    /// The chart is one element, each figure another, every key with its Russian.
    @Test(arguments: Language.allCases)
    func eachPartIsOneElement(_ language: Language) throws {
        let localize = WidgetAccessibilityTests.localize(language)
        let f = try WidgetTextBudgetTests.formatter(language)
        let feed = WidgetFeed.sample(at: Self.now)
        for series in HistoryWidgetSeries.allCases {
            for period in HistoryWidgetPeriod.allCases {
                let plan = Self.plan(
                    .large, HistoryWidgetConfiguration(period: period, series: series), feed: feed, formatter: f)
                guard case .history(let layout) = plan else {
                    Issue.record("\(series), \(period): \(plan)")
                    continue
                }
                let elements = WidgetAccessibility.elements(plan)
                #expect(elements == [layout.chart.summary.spokenLabel] + layout.statistics.map(\.spokenLabel))
                #expect(layout.statistics.count == 3)
                for element in elements {
                    let text = try #require(element.text(localize))
                    #expect(!text.contains("%@"), "\(text)")
                }
                for key in elements.flatMap(\.keys) {
                    #expect(try WidgetTextBudgetTests.text(key, .russian)?.isEmpty == false, "\(key)")
                }
            }
        }
        #expect(
            WidgetAccessibility.elements(HistoryWidgetPlan.empty(.recordingOff)) == [
                HistoryWidgetEmptyReason.recordingOff.spokenLabel
            ])
    }

    /// Hourly, with an entry once the feed is two hours old, at least 15 minutes after the first.
    @Test func theTimelineRefreshesHourlyAndSaysWhenTheFeedIsOld() {
        let written = Self.now
        let plan = WidgetTimelinePlan.history(writtenAt: written, at: written.addingTimeInterval(10 * 60))
        #expect(
            plan.entries.map(\.date) == [written.addingTimeInterval(10 * 60), written.addingTimeInterval(2 * 3600)])
        #expect(plan.entries.map(\.isStale) == [false, true])
        #expect(plan.nextReload == written.addingTimeInterval(70 * 60))
        // Nearly two hours old: the old feed's entry waits the least interval.
        let late = WidgetTimelinePlan.history(writtenAt: written, at: written.addingTimeInterval(115 * 60))
        #expect(
            late.entries.map(\.date) == [written.addingTimeInterval(115 * 60), written.addingTimeInterval(130 * 60)])
        // Already old, and no feed: one entry.
        let old = WidgetTimelinePlan.history(writtenAt: written, at: written.addingTimeInterval(3 * 3600))
        #expect(old.entries.map(\.isStale) == [true])
        #expect(WidgetTimelinePlan.history(writtenAt: nil, at: written).entries.count == 1)
        for plan in [plan, late, old] {
            #expect(plan.entries.count <= WidgetTimelinePlan.maximumEntries)
        }
    }
}

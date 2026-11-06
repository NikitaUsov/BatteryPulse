import Foundation

/// What a placed History widget is set to show: the widget's configuration intent maps to it one
/// to one. The defaults chart the last 24 hours' charge, with the statistics in large.
public struct HistoryWidgetConfiguration: Sendable, Equatable {
    /// Ignored by the 90-day series (``HistoryWidgetSeries/isDaily``).
    public var period: HistoryWidgetPeriod
    public var series: HistoryWidgetSeries
    /// Large only: the figures of ``statisticsPeriod`` under the chart.
    public var showsStatistics: Bool

    public init(period: HistoryWidgetPeriod = .day, series: HistoryWidgetSeries = .charge, showsStatistics: Bool = true)
    {
        self.period = period
        self.series = series
        self.showsStatistics = showsStatistics
    }

    /// The period of the large widget's figures, as the History page shows them for its own: the
    /// chart's, and the last 7 days under a 90-day series, the longer of the page's two.
    public var statisticsPeriod: HistoryWidgetPeriod {
        series.isDaily ? .week : period
    }
}

/// What one timeline entry of the History widget shows, decided in BatteryCore so it is tested on
/// Linux; the widget only strokes the chart's points and draws the words.
///
/// Its data is the feed the app writes (``WidgetFeed``), the widget's only way to the history: no
/// feed, recording off and nothing recorded each show a message, and a feed over two hours old
/// shows its last data with its times and "Open BatteryPulse to update". Every state opens
/// History.
public enum HistoryWidgetPlan: Sendable, Equatable {
    case history(HistoryWidgetLayout)
    case empty(HistoryWidgetEmptyReason)

    /// The plan for `entry` of a timeline whose read found `feed`; `nil` means no feed (none
    /// written, or one the reader turned down). Times are in `formatter`'s locale and `timeZone`.
    public static func make(
        size: WidgetSize, configuration c: HistoryWidgetConfiguration, feed: WidgetFeed?,
        entry: WidgetTimelinePlan.Entry, formatter: BatteryFormatter, timeZone: TimeZone
    ) -> HistoryWidgetPlan {
        switch WidgetChartContent.make(
            c.series, period: c.period, feed: feed, at: entry.date, formatter: formatter, timeZone: timeZone)
        {
        case .message(let reason):
            return .empty(reason)
        case .chart(let chart, let isOutdated):
            let statistics =
                size != .small && size != .medium && c.showsStatistics
                ? HistoryWidgetStatistic.all(feed?.statistics(for: c.statisticsPeriod), formatter: formatter) : []
            return .history(HistoryWidgetLayout(chart: chart, statistics: statistics, isOutdated: isOutdated))
        }
    }

    /// Every state opens History, which shows the series or says how to start recording.
    public var route: WidgetRoute {
        WidgetRoute(widgetPage: .history)
    }
}

/// The History widget's content for one entry.
public struct HistoryWidgetLayout: Sendable, Equatable {
    public var chart: WidgetChart
    /// Large with Statistics on: the figures of the configuration's
    /// ``HistoryWidgetConfiguration/statisticsPeriod``, in order.
    public var statistics: [HistoryWidgetStatistic]
    /// The feed is over two hours old: "Open BatteryPulse to update" under its last data.
    public var isOutdated: Bool
}

// MARK: - Statistics

/// One of the figures the large History widget shows under its chart, the last 24 hours' or 7
/// days', as the History page shows them for its period.
public struct HistoryWidgetStatistic: Sendable, Equatable {
    public enum Kind: Sendable, Equatable, CaseIterable {
        case averageDrain, onBattery, chargingSessions
    }

    public var kind: Kind
    /// Pre-formatted; "—" without the figure.
    public var value: WidgetValue

    /// Each figure of `statistics`, in order; each "—" without them.
    static func all(_ statistics: WidgetFeed.Statistics?, formatter f: BatteryFormatter) -> [HistoryWidgetStatistic] {
        Kind.allCases.map { kind in
            let value: WidgetValue
            switch kind {
            case .averageDrain:
                value = WidgetValue.averageDrain(statistics?.averageDrainPercentPerHour, f)
            case .onBattery:
                value =
                    statistics.map { .text(f.duration(minutes: Int((Double($0.timeOnBattery) / 60).rounded()))) }
                    ?? .text(WidgetValue.missing)
            case .chargingSessions:
                value = .text(
                    statistics.map { $0.chargingSessions.formatted(.number.locale(f.locale)) } ?? WidgetValue.missing)
            }
            return HistoryWidgetStatistic(kind: kind, value: value)
        }
    }

    /// "Average drain, 8.2% per hour".
    public var spokenLabel: WidgetSpokenLabel {
        .phrases([.key(kind.labelKey)] + value.phrases)
    }
}

// MARK: - VoiceOver

extension WidgetAccessibility {
    /// Every element of the History widget's `plan`, in the order it shows them: the chart with
    /// its name and latest value, the figures, then "Open BatteryPulse to update".
    static func elements(_ plan: HistoryWidgetPlan) -> [WidgetSpokenLabel] {
        switch plan {
        case .empty(let reason):
            return [reason.spokenLabel]
        case .history(let layout):
            return [layout.chart.summary.spokenLabel] + layout.statistics.map(\.spokenLabel)
                + (layout.isOutdated ? [HistoryWidgetEmptyReason.outdatedLabel] : [])
        }
    }
}

// The catalog keys of the History widget's own words, the same keys its views use (a macOS test
// compares them).

extension HistoryWidgetStatistic.Kind {
    /// The History page's names for its figures.
    var labelKey: String {
        switch self {
        case .averageDrain: "Average drain"
        case .onBattery: "On battery"
        case .chargingSessions: "Charging sessions"
        }
    }
}

import Foundation

/// What a chart's place shows: the chart, or why there is none. The chart is boxed, so the layouts
/// and views that hold one stay small to copy.
public enum WidgetChartContent: Sendable, Equatable {
    /// `isOutdated`: the feed is over two hours old, so "Open BatteryPulse to update" shows with it.
    indirect case chart(WidgetChart, isOutdated: Bool)
    case message(HistoryWidgetEmptyReason)

    /// `series` over `period` from `feed` at `date`, the entry's.
    static func make(
        _ series: HistoryWidgetSeries, period: HistoryWidgetPeriod, feed: WidgetFeed?, at date: Date,
        formatter: BatteryFormatter, timeZone: TimeZone
    ) -> WidgetChartContent {
        guard let feed else { return .message(.noFeed) }
        guard feed.recordsHistory else { return .message(.recordingOff) }
        guard
            let chart = WidgetChart(
                series, period: period, feed: feed, formatter: formatter, timeZone: timeZone)
        else { return .message(.noHistory) }
        return .chart(chart, isOutdated: feed.isOutdated(at: date))
    }
}

extension WidgetFeed {
    /// A feed older than this says the app hasn't run for a while: its widgets add "Open
    /// BatteryPulse to update" to its last data. The app writes it at least once per 15 minutes
    /// while it runs.
    public static let outdatedAge: TimeInterval = 2 * 60 * 60

    /// Whether the feed is ``outdatedAge`` old or older at `date`.
    func isOutdated(at date: Date) -> Bool {
        date.timeIntervalSince(writtenAt) >= Self.outdatedAge
    }
}

/// Why the History widget, or the large Battery widget's chart, shows a message instead of a
/// chart: one line, and a click opens History.
public enum HistoryWidgetEmptyReason: Sendable, Equatable, CaseIterable {
    /// No feed: BatteryPulse hasn't written one since it was installed, or the widget couldn't
    /// read it ("Open BatteryPulse to update").
    case noFeed
    /// Record battery history is off ("Turn on Record battery history in BatteryPulse").
    case recordingOff
    /// Nothing recorded for the series yet ("No History Yet").
    case noHistory
}

// MARK: - The chart

/// One series as the widget strokes it, in a unit square: x from 0 at the time axis's start to 1
/// at its end, y from 0 at the value axis's bottom to 1 at its top. The widget scales it to its
/// place and draws it as a `Path`, with the axes' labels pre-formatted. In every rendering mode the
/// line, the charging stretches and battery power's zero line differ by alpha, line style and
/// position, never by hue alone.
public struct WidgetChart: Sendable, Equatable {
    public var series: HistoryWidgetSeries
    /// The line, in runs between gaps (BatteryPulse not running, or the Mac asleep), each in time
    /// order; a run of one point is a dot. The daily summaries' line runs across a missing day, as
    /// the History page's does; the cycle count's is drawn in steps.
    public var runs: [[WidgetChartPoint]]
    /// The stretches on the adapter, shaded behind the line.
    public var pluggedSpans: [WidgetChartSpan]
    /// Battery power's zero, between charging above and draining below.
    public var zero: Double?
    /// The value axis's bottom and top.
    public var bottomLabel: String
    public var topLabel: String
    /// The time axis's start and end: clock times over 24 hours, days over 7 and 90; the end is when
    /// the app last wrote the feed, or its last day.
    public var startLabel: String
    public var endLabel: String
    /// The series' last value, which the History widget shows beside its name.
    public var latest: String
    /// The chart's one VoiceOver label.
    public var summary: WidgetChartSummary

    /// `nil` when `feed` holds no value of the series.
    init?(
        _ series: HistoryWidgetSeries, period: HistoryWidgetPeriod, feed: WidgetFeed, formatter f: BatteryFormatter,
        timeZone: TimeZone
    ) {
        let values: [Double?]
        let start: Date
        let end: Date
        var plugged: [Bool?] = []
        let span: WidgetChartSummary.Span
        let dates: Date.FormatStyle
        if series.isDaily {
            guard let daily = feed.daily,
                let first = HistoryDay(day: daily.firstDay).date(gregorian: HistoryDay.gregorian(in: timeZone))
            else { return nil }
            values =
                series == .cycleCount
                ? daily.cycleCount.map { $0.map(Double.init) }
                : daily.capacityToDesign10.map { $0.map { Double($0) / 10 } }
            start = first
            end = first.addingTimeInterval(TimeInterval(max(0, values.count - 1)) * 24 * 60 * 60)
            span = .days90
            dates = Self.dayStyle(f, timeZone)
        } else {
            guard let steps = period == .day ? feed.day : feed.week else { return nil }
            values = steps.values(series)
            plugged = steps.plugged
            start = steps.start
            end = min(feed.writtenAt, steps.date(ofStep: steps.count))
            span = period == .day ? .hours24 : .days7
            dates =
                period == .day
                ? Date.FormatStyle(date: .omitted, time: .shortened, locale: f.locale, timeZone: timeZone)
                : Self.dayStyle(f, timeZone)
        }
        let present = values.compactMap { $0 }
        guard let low = present.min(), let high = present.max(), let last = present.last else { return nil }
        let axis = series.axis(low: low, high: high)
        let count = Double(values.count)
        func point(_ index: Int, _ value: Double) -> WidgetChartPoint {
            WidgetChartPoint(
                x: (Double(index) + 0.5) / count, y: (value - axis.lowerBound) / (axis.upperBound - axis.lowerBound))
        }
        var runs: [[WidgetChartPoint]] = []
        var run: [WidgetChartPoint] = []
        for (index, value) in values.enumerated() {
            guard let value else {
                // The daily summaries' line runs across a missing day.
                if !series.isDaily, !run.isEmpty {
                    runs.append(run)
                    run = []
                }
                continue
            }
            let next = point(index, value)
            if series == .cycleCount, let previous = run.last, previous.y != next.y {
                run.append(WidgetChartPoint(x: next.x, y: previous.y))
            }
            run.append(next)
        }
        if !run.isEmpty { runs.append(run) }
        self.series = series
        self.runs = runs
        pluggedSpans = Self.spans(plugged)
        zero = series == .batteryPower ? (0 - axis.lowerBound) / (axis.upperBound - axis.lowerBound) : nil
        bottomLabel = series.axisLabel(axis.lowerBound, f)
        topLabel = series.axisLabel(axis.upperBound, f)
        startLabel = start.formatted(dates)
        endLabel = end.formatted(dates)
        latest = series.valueLabel(last, f)
        summary = WidgetChartSummary(
            series: series, span: span, lowest: series.valueLabel(low, f), highest: series.valueLabel(high, f),
            latest: latest)
    }

    /// "Oct 30", in the formatter's locale, as it orders a day and its month.
    private static func dayStyle(_ f: BatteryFormatter, _ timeZone: TimeZone) -> Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .omitted, locale: f.locale, timeZone: timeZone).month(.abbreviated).day()
    }

    /// The runs of steps on the adapter, each from its first step's start to its last one's end.
    static func spans(_ plugged: [Bool?]) -> [WidgetChartSpan] {
        let count = Double(plugged.count)
        var spans: [WidgetChartSpan] = []
        var start: Int?
        for (index, value) in (plugged + [nil]).enumerated() {
            if value == true {
                if start == nil { start = index }
            } else if let first = start {
                spans.append(WidgetChartSpan(start: Double(first) / count, end: Double(index) / count))
                start = nil
            }
        }
        return spans
    }
}

/// A point of a chart's line, in its unit square.
public struct WidgetChartPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double
}

/// A stretch of a chart's time axis, in its unit square.
public struct WidgetChartSpan: Sendable, Equatable {
    public var start: Double
    public var end: Double
}

extension WidgetFeed.Series {
    /// The series' values in their own units: percent, watts, °C.
    func values(_ series: HistoryWidgetSeries) -> [Double?] {
        switch series {
        case .charge: percent.map { $0.map(Double.init) }
        case .batteryPower: batteryWatts10.map { $0.map { Double($0) / 10 } }
        case .temperature: temperature10.map { $0.map { Double($0) / 10 } }
        case .capacityToDesign, .cycleCount: []
        }
    }
}

extension HistoryWidgetSeries {
    /// The value axis for values from `low` to `high`: the charge's whole range, battery power's
    /// with its zero, the others' rounded out to whole units, each at least a few units tall so a
    /// flat line sits in the middle.
    func axis(low: Double, high: Double) -> ClosedRange<Double> {
        switch self {
        case .charge: 0...100
        case .batteryPower: Self.rounded(min(low, 0), max(high, 0), step: 5, minimumSpan: 10)
        case .temperature: Self.rounded(low, high, step: 1, minimumSpan: 4)
        case .capacityToDesign: Self.rounded(low, high, step: 1, minimumSpan: 2)
        case .cycleCount: Self.rounded(low, high, step: 1, minimumSpan: 4)
        }
    }

    /// `low...high` with its ends rounded out to multiples of `step`, widened to at least
    /// `minimumSpan`, half of the room below it in whole steps and the rest above.
    static func rounded(_ low: Double, _ high: Double, step: Double, minimumSpan: Double) -> ClosedRange<Double> {
        var bottom = (low / step).rounded(.down) * step
        var top = (high / step).rounded(.up) * step
        if top - bottom < minimumSpan {
            bottom -= ((minimumSpan - (top - bottom)) / 2 / step).rounded(.down) * step
            top = bottom + (minimumSpan / step).rounded(.up) * step
        }
        return bottom...top
    }

    /// A value as the chart's header and VoiceOver say it: "54%", "−8.4 W", "31.2 °C", "98.5%",
    /// "123".
    func valueLabel(_ value: Double, _ f: BatteryFormatter) -> String {
        switch self {
        case .charge: f.percent(value)
        case .batteryPower: f.watts(value, signed: true)
        case .temperature: f.celsius(value)
        case .capacityToDesign: f.percent(value, fractionDigits: 1)
        case .cycleCount: Int(value.rounded()).formatted(.number.locale(f.locale))
        }
    }

    /// An end of the value axis, in whole units: "100%", "−10 W", "34 °C".
    func axisLabel(_ value: Double, _ f: BatteryFormatter) -> String {
        switch self {
        case .charge, .capacityToDesign: f.percent(value)
        case .batteryPower: f.watts(value, fractionDigits: 0, signed: true)
        case .temperature: f.celsius(value, fractionDigits: 0)
        case .cycleCount: Int(value.rounded()).formatted(.number.locale(f.locale))
        }
    }
}

/// A chart's one VoiceOver label (HIG Charts: a small chart gets one succinct label): the series,
/// its span, and its lowest, highest and latest values. No counted phrase: every number is a
/// value beside a label.
public struct WidgetChartSummary: Sendable, Equatable {
    /// The time a chart spans.
    public enum Span: Sendable, Equatable, CaseIterable {
        case hours24, days7, days90
    }

    public var series: HistoryWidgetSeries
    public var span: Span
    public var lowest: String
    public var highest: String
    public var latest: String

    /// "Charge, 24 Hours, Lowest 31%, highest 100%, latest 54%".
    public var spokenLabel: WidgetSpokenLabel {
        .phrases([
            .key(series.titleKey), .key(span.titleKey),
            .key("Lowest %@, highest %@, latest %@", [.verbatim(lowest), .verbatim(highest), .verbatim(latest)]),
        ])
    }
}

extension WidgetValue {
    /// What a value without its figure shows.
    static let missing = "—"

    /// "8.2% per hour", as the History page shows the average drain; "—" without one.
    static func averageDrain(_ percentPerHour: Double?, _ f: BatteryFormatter) -> WidgetValue {
        percentPerHour.map { .perHour(f.percent($0, fractionDigits: 1)) } ?? .text(missing)
    }
}

// MARK: - VoiceOver

extension WidgetAccessibility {
    /// The elements of a chart's place: the chart and, when the feed is old, its line; or the
    /// message.
    static func elements(_ content: WidgetChartContent) -> [WidgetSpokenLabel] {
        switch content {
        case .chart(let chart, let isOutdated):
            [chart.summary.spokenLabel] + (isOutdated ? [HistoryWidgetEmptyReason.outdatedLabel] : [])
        case .message(let reason): [reason.spokenLabel]
        }
    }
}

extension HistoryWidgetEmptyReason {
    /// The message the widget shows.
    public var spokenLabel: WidgetSpokenLabel {
        .phrases([.key(messageKey)])
    }

    var messageKey: String {
        switch self {
        case .noFeed: Self.outdatedKey
        case .recordingOff: "Turn on Record battery history in BatteryPulse"
        case .noHistory: "No History Yet"
        }
    }

    /// The line under a feed's last data once it is two hours old, and the message without a
    /// feed.
    static let outdatedKey = "Open BatteryPulse to update"
    static let outdatedLabel = WidgetSpokenLabel.phrases([.key(outdatedKey)])
}

// The catalog keys of a chart's words, the same keys the widget's views use (a macOS test
// compares them).

extension HistoryWidgetSeries {
    /// The series' name, as the History page and the edit sheet name it.
    var titleKey: String {
        switch self {
        case .charge: "Charge"
        case .batteryPower: "Battery power"
        case .temperature: "Temperature"
        case .capacityToDesign: "Capacity compared with design"
        case .cycleCount: "Cycle count"
        }
    }
}

extension WidgetChartSummary.Span {
    var titleKey: String {
        switch self {
        case .hours24: "24 Hours"
        case .days7: "7 Days"
        case .days90: "90 Days"
        }
    }
}

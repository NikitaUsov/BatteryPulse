import Foundation

// What VoiceOver and Audio Graphs say about the History page's charts, built here so it is tested
// on Linux; the app maps each summary to an `AXChartDescriptor` (`accessibilityChartDescriptor(_:)`).
//
// - One summary per chart: Charge, Power and Temperature from the period's chart data, Capacity and
//   Cycles from the daily summaries. A summary has a series for each line of the chart that has a
//   value, in the order the chart draws them: a device's Power has no Mac line, and an empty period
//   gives a summary without series.
// - A series has at most 48 points: clock hours for the last 24 hours, calendar days for the last 7,
//   and for the daily summaries as many whole days per point as keep them to 48. A point is the
//   mean of the chart's values in its stretch (the cycle count's latest), and a stretch without a
//   value is a gap: a point without a value, never a 0.
// - The extremes and the first and last values are the chart's own values, not the points' means.
//   Only values on the chart's time axis count, as only they show.
// - Every number and time comes formatted, in the formatter's locale and the given time zone: the
//   numbers as the chart's hover readout shows them (the Mac's without a sign), a point's time by
//   the stretch it stands for, and no two points of a summary alike.

/// The name of a chart's series: a catalog key, keyed by the English text the charts' marks and
/// legend already use.
public enum ChartSeriesName: String, Sendable, CaseIterable {
    /// The charge line.
    case charge = "Charge"
    /// The power into the battery: positive while charging, negative while discharging.
    case battery = "Battery"
    /// What the Mac draws.
    case mac = "Mac"
    /// The battery's temperature.
    case temperature = "Temperature"
    /// The capacity compared with design, from the daily summaries.
    case capacity = "Capacity"
    /// The cycle count, from the daily summaries.
    case cycles = "Cycles"

    /// The catalog key.
    public var key: String { rawValue }

    /// How the series' numbers read.
    public var unit: ChartUnit {
        switch self {
        case .charge: .percent(fractionDigits: 0)
        case .battery: .watts(signed: true)
        case .mac: .watts(signed: false)
        case .temperature: .celsius
        case .capacity: .percent(fractionDigits: 1)
        case .cycles: .count
        }
    }

    /// Whether a point is the latest value of its stretch rather than the mean: a count only
    /// rises, and the mean of 312 and 313 cycles is no cycle count.
    var takesLatest: Bool { self == .cycles }
}

/// How a series' numbers read.
public enum ChartUnit: Sendable, Equatable {
    /// A percentage with `fractionDigits` decimals: the charge whole, the capacity with one.
    case percent(fractionDigits: Int)
    /// Watts with one decimal; `signed` for the battery, whose sign says whether it charges.
    case watts(signed: Bool)
    /// Degrees Celsius with one decimal.
    case celsius
    /// A whole number: the cycle count.
    case count

    /// `value` as the chart's hover readout or the Health page shows it, but the Mac's watts
    /// without the readout's sign: what the Mac draws is never negative.
    public func text(_ value: Double, formatter: BatteryFormatter) -> String {
        switch self {
        case .percent(let fractionDigits): formatter.percent(value, fractionDigits: fractionDigits)
        case .watts(let signed): formatter.watts(value, signed: signed)
        case .celsius: formatter.celsius(value)
        case .count: formatter.number(value, fractionDigits: 0)
        }
    }
}

/// What VoiceOver and Audio Graphs read about one of the History page's charts: for each line its
/// name, unit, first and last value, lowest and highest value and at most
/// ``ChartSummary/maximumPoints`` points, every number and time formatted. Built off the main actor
/// with the chart data, from ``HistoryChartData`` or the daily summaries' ``HistoryDayPoint``s.
public struct ChartSummary: Sendable, Equatable {
    /// Which chart.
    public enum Kind: Sendable, Equatable {
        case charge, power, temperature, capacity, cycles
    }

    /// How long a point's stretch is.
    public enum Resolution: Sendable, Equatable {
        /// `count` clock hours, from the start of an hour.
        case hours(Int)
        /// `count` calendar days, from midnight.
        case days(Int)
    }

    /// A time and how it reads.
    public struct Moment: Sendable, Equatable {
        public var date: Date
        public var text: String
    }

    /// A number and how it reads.
    public struct Value: Sendable, Equatable {
        public var number: Double
        public var text: String
    }

    /// A line's lowest or highest value and when the chart first shows it.
    public struct Extreme: Sendable, Equatable {
        public var value: Value
        public var time: Moment
    }

    /// One stretch of a line.
    public struct Point: Sendable, Equatable {
        /// The stretch's start, read by the stretch's length: a weekday and a time for an hour, a
        /// date for a day or more.
        public var time: Moment
        /// The mean of the chart's values in the stretch (the cycle count's latest); `nil` where
        /// it has none: a gap, never a 0.
        public var value: Value?
    }

    /// One line of the chart, with at least one value.
    public struct Series: Sendable, Equatable {
        public var name: ChartSeriesName
        /// The line's first and last value's times.
        public var first: Moment
        public var last: Moment
        public var minimum: Extreme
        public var maximum: Extreme
        /// The stretches that cover the time axis, in order, at most ``ChartSummary/maximumPoints``.
        public var points: [Point]

        /// The series' name as a catalog key.
        public var nameKey: String { name.key }
        public var unit: ChartUnit { name.unit }
    }

    /// The most points a line has. An hour's take 24 or 25 for a day and a day's 8 for a week; the
    /// daily summaries, which grow for good, take as many days per point as keep them to this.
    public static let maximumPoints = 48

    public var kind: Kind
    /// The period the History page shows; `nil` for the health trends, which cover every day.
    public var period: HistoryPeriod?
    public var resolution: Resolution
    /// The time axis's ends: the period up to the chart's end, or a health trend's first and last
    /// day.
    public var start: Moment
    public var end: Moment
    /// The lines with a value, in the order the chart draws them.
    public var series: [Series]

    /// Whether no line has a value, as for an empty period.
    public var isEmpty: Bool { series.isEmpty }
}

extension ChartSummary {
    /// The Charge chart of `data`: one line.
    public static func charge(
        _ data: HistoryChartData, formatter: BatteryFormatter, timeZone: TimeZone = .current
    ) -> ChartSummary {
        period(
            .charge, data, lines: [(.charge, data.charge.map { Sample(time: $0.time, value: $0.value) })],
            formatter: formatter, timeZone: timeZone)
    }

    /// The Power chart of `data`: the battery's line, then the Mac's, which a device doesn't have.
    public static func power(
        _ data: HistoryChartData, formatter: BatteryFormatter, timeZone: TimeZone = .current
    ) -> ChartSummary {
        var battery: [Sample] = []
        var mac: [Sample] = []
        for value in data.power {
            switch value.line {
            case .battery: battery.append(Sample(time: value.time, value: value.watts))
            case .systemLoad: mac.append(Sample(time: value.time, value: value.watts))
            }
        }
        return period(
            .power, data, lines: [(.battery, battery), (.mac, mac)], formatter: formatter, timeZone: timeZone)
    }

    /// The Temperature chart of `data`: one line, or none when the page hides the chart.
    public static func temperature(
        _ data: HistoryChartData, formatter: BatteryFormatter, timeZone: TimeZone = .current
    ) -> ChartSummary {
        period(
            .temperature, data,
            lines: [(.temperature, data.temperature.map { Sample(time: $0.time, value: $0.value) })],
            formatter: formatter, timeZone: timeZone)
    }

    /// The capacity compared with design over `days`; `nil` when no day has it. `timeZone` is the
    /// one the days were placed at noon in.
    public static func capacity(
        _ days: [HistoryDayPoint], formatter: BatteryFormatter, timeZone: TimeZone = .current
    ) -> ChartSummary? {
        let samples = days.compactMap { point in
            point.day.capacityToDesignPercent.map { Sample(time: point.date, value: $0) }
        }
        return trend(.capacity, .capacity, samples, formatter: formatter, timeZone: timeZone)
    }

    /// The cycle count over `days`; `nil` when no day has it.
    public static func cycles(
        _ days: [HistoryDayPoint], formatter: BatteryFormatter, timeZone: TimeZone = .current
    ) -> ChartSummary? {
        let samples = days.compactMap { point in
            point.day.cycleCount.map { Sample(time: point.date, value: Double($0)) }
        }
        return trend(.cycles, .cycles, samples, formatter: formatter, timeZone: timeZone)
    }
}

extension ChartSummary {
    /// A value of a line at a time.
    struct Sample {
        var time: Date
        var value: Double
    }

    /// How a summary's times read.
    enum TimeStyle {
        /// The last 24 hours: a weekday and a time.
        case hours
        /// The last 7 days: a weekday and a date, with the time for a moment.
        case week
        /// The daily summaries: dates.
        case dates
    }

    /// A chart of the period on the History page: its time axis is the period up to the data's end.
    static func period(
        _ kind: Kind, _ data: HistoryChartData, lines: [(ChartSeriesName, [Sample])], formatter: BatteryFormatter,
        timeZone: TimeZone
    ) -> ChartSummary {
        let isDay = data.period == .day
        return make(
            kind, period: data.period, range: data.end.addingTimeInterval(-data.period.length)...data.end,
            resolution: isDay ? .hours(1) : .days(1), style: isDay ? .hours : .week, lines: lines,
            formatter: formatter, timeZone: timeZone)
    }

    /// A health trend: its time axis runs from the first day with a value to the last, a day per
    /// point while that keeps to ``ChartSummary/maximumPoints``.
    static func trend(
        _ kind: Kind, _ name: ChartSeriesName, _ samples: [Sample], formatter: BatteryFormatter, timeZone: TimeZone
    ) -> ChartSummary? {
        guard let first = samples.min(by: { $0.time < $1.time }), let last = samples.max(by: { $0.time < $1.time })
        else { return nil }
        let calendar = HistoryDay.gregorian(in: timeZone)
        let elapsed = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: first.time), to: calendar.startOfDay(for: last.time)
        )
        .day
        let days = (elapsed ?? 0) + 1
        let perPoint = max(1, (days + maximumPoints - 1) / maximumPoints)
        return make(
            kind, period: nil, range: first.time...last.time, resolution: .days(perPoint), style: .dates,
            lines: [(name, samples)], formatter: formatter, timeZone: timeZone)
    }

    static func make(
        _ kind: Kind, period: HistoryPeriod?, range: ClosedRange<Date>, resolution: Resolution, style: TimeStyle,
        lines: [(ChartSeriesName, [Sample])], formatter: BatteryFormatter, timeZone: TimeZone
    ) -> ChartSummary {
        let clock = Clock(style, locale: formatter.locale, timeZone: timeZone)
        let starts = stretchStarts(
            covering: range, resolution: resolution, calendar: HistoryDay.gregorian(in: timeZone))
        let times = clock.points(starts)
        let series = lines.compactMap { name, samples in
            Series(
                name, samples: samples.filter { range.contains($0.time) }, starts: starts, times: times, clock: clock,
                formatter: formatter)
        }
        return ChartSummary(
            kind: kind, period: period, resolution: resolution, start: clock.moment(range.lowerBound),
            end: clock.moment(range.upperBound), series: series)
    }

    /// The starts of the stretches that cover `range`, `resolution` apart in `calendar`, the first at
    /// the start of the hour or day `range` begins in. Never more than ``ChartSummary/maximumPoints``:
    /// the last stretch would then take the rest.
    static func stretchStarts(covering range: ClosedRange<Date>, resolution: Resolution, calendar: Calendar) -> [Date] {
        let (component, count): (Calendar.Component, Int) =
            switch resolution {
            case .hours(let count): (.hour, max(1, count))
            case .days(let count): (.day, max(1, count))
            }
        let origin = calendar.dateInterval(of: component, for: range.lowerBound)?.start ?? range.lowerBound
        var starts = [origin]
        // Each start counts from the origin, so a day stays at midnight across a clock change.
        while starts.count < maximumPoints,
            let next = calendar.date(byAdding: component, value: count * starts.count, to: origin),
            next < range.upperBound
        {
            starts.append(next)
        }
        return starts
    }

    /// The index of the stretch `time` falls in: the last of `starts` at or before it, the first for
    /// a time before them all.
    static func stretchIndex(of time: Date, in starts: [Date]) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= time { low = middle + 1 } else { high = middle }
        }
        return max(0, low - 1)
    }

    /// The date formats of a summary, built once for all its times.
    struct Clock {
        let pointStyle: Date.FormatStyle
        /// A point's style with its zone, for an hour a clock set back reads twice.
        let zonedPointStyle: Date.FormatStyle
        let momentStyle: Date.FormatStyle

        init(_ style: TimeStyle, locale: Locale, timeZone: TimeZone) {
            var calendar = locale.calendar
            calendar.timeZone = timeZone
            let base = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            switch style {
            case .hours:
                pointStyle = base.weekday(.wide).hour().minute()
                momentStyle = pointStyle
            case .week:
                pointStyle = base.weekday(.wide).month(.wide).day()
                momentStyle = pointStyle.hour().minute()
            case .dates:
                pointStyle = base.year().month(.wide).day()
                momentStyle = pointStyle
            }
            zonedPointStyle = pointStyle.timeZone(.specificName(.short))
        }

        /// The points of the stretches that begin at `starts`, each read by its start. Where a clock
        /// is set back, the repeated hour's two points name their zone ("1:00 AM EDT", "1:00 AM
        /// EST"), so no two points read the same.
        func points(_ starts: [Date]) -> [ChartSummary.Moment] {
            let texts = starts.map { $0.formatted(pointStyle) }
            let uses = Dictionary(texts.map { ($0, 1) }, uniquingKeysWith: +)
            return zip(starts, texts).map { date, text in
                ChartSummary.Moment(
                    date: date, text: uses[text, default: 0] > 1 ? date.formatted(zonedPointStyle) : text)
            }
        }

        func moment(_ date: Date) -> ChartSummary.Moment {
            ChartSummary.Moment(date: date, text: date.formatted(momentStyle))
        }
    }
}

extension ChartSummary.Series {
    /// The line `name` of `samples`, the chart's values on its time axis, over the stretches that
    /// begin at `starts` and read as `times`; `nil` without a value.
    init?(
        _ name: ChartSeriesName, samples: [ChartSummary.Sample], starts: [Date], times: [ChartSummary.Moment],
        clock: ChartSummary.Clock, formatter: BatteryFormatter
    ) {
        guard var first = samples.first else { return nil }
        var last = first
        var lowest = first
        var highest = first
        var sums = [Double](repeating: 0, count: starts.count)
        var counts = [Int](repeating: 0, count: starts.count)
        var latest = [ChartSummary.Sample?](repeating: nil, count: starts.count)
        for sample in samples {
            if sample.time < first.time { first = sample }
            if sample.time > last.time { last = sample }
            // The earliest of equal extremes: the first time the chart shows it.
            if sample.value < lowest.value || (sample.value == lowest.value && sample.time < lowest.time) {
                lowest = sample
            }
            if sample.value > highest.value || (sample.value == highest.value && sample.time < highest.time) {
                highest = sample
            }
            let index = ChartSummary.stretchIndex(of: sample.time, in: starts)
            sums[index] += sample.value
            counts[index] += 1
            if latest[index].map({ sample.time >= $0.time }) ?? true { latest[index] = sample }
        }
        let unit = name.unit
        func value(_ number: Double) -> ChartSummary.Value {
            ChartSummary.Value(number: number, text: unit.text(number, formatter: formatter))
        }
        func extreme(_ sample: ChartSummary.Sample) -> ChartSummary.Extreme {
            ChartSummary.Extreme(value: value(sample.value), time: clock.moment(sample.time))
        }
        self.name = name
        self.first = clock.moment(first.time)
        self.last = clock.moment(last.time)
        minimum = extreme(lowest)
        maximum = extreme(highest)
        points = times.indices.map { index in
            guard counts[index] > 0 else { return ChartSummary.Point(time: times[index], value: nil) }
            let mean = sums[index] / Double(counts[index])
            let number = name.takesLatest ? latest[index]?.value ?? mean : mean
            return ChartSummary.Point(time: times[index], value: value(number))
        }
    }
}

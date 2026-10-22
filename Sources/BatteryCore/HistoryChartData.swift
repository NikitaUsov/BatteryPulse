import Foundation

/// A period the History page shows: the last 24 hours or the last 7 days.
public enum HistoryPeriod: Sendable {
    case day, week

    public var length: TimeInterval { self == .day ? 24 * 60 * 60 : 7 * 24 * 60 * 60 }

    /// Minute samples for a day; ten-minute averages for a week (about 1,000 points).
    public var bucket: TimeInterval? { self == .day ? nil : 10 * 60 }
}

/// Everything the History page's period charts and figures show, built once per load off the main
/// actor, so the view only assigns it.
public struct HistoryChartData: Sendable, Equatable {
    public var period: HistoryPeriod
    /// The right edge of the time axis.
    public var end: Date
    /// The samples prepared for the charts: averaged into the period's buckets, split at gaps.
    public var points: [HistoryPoint]
    /// The stretches on the power adapter, shaded behind the charge line.
    public var spans: [HistorySpan]
    /// The period's figures; `nil` without samples, or when they weren't asked for.
    public var statistics: HistoryStatistics?
    /// The charge line: the points that have a charge.
    public var charge: [HistoryChartValue]
    /// The two power lines, in the order the chart draws them: for each point the battery's value,
    /// then the Mac's.
    public var power: [HistoryPowerValue]
    /// The temperature line: the points that have a temperature.
    public var temperature: [HistoryChartValue]

    /// Whether the temperature chart has a line to draw.
    public var hasTemperature: Bool { !temperature.isEmpty }

    /// No data: what the page shows before its first load.
    public init(period: HistoryPeriod, end: Date) {
        self.period = period
        self.end = end
        points = []
        spans = []
        statistics = nil
        charge = []
        power = []
        temperature = []
    }

    /// The charts and figures for `samples`, the raw samples of `period` up to `end`.
    /// `includesStatistics` is false for a device sampled only while on a cable, where drain and
    /// time on battery mean nothing.
    public static func make(
        samples: [HistorySample], period: HistoryPeriod, end: Date, includesStatistics: Bool
    ) -> HistoryChartData {
        var data = HistoryChartData(period: period, end: end)
        data.points = HistoryPoint.points(from: samples, bucket: period.bucket)
        data.spans = HistorySpan.spans(from: samples)
        data.statistics = includesStatistics && !samples.isEmpty ? HistoryStatistics(samples: samples) : nil
        // The lines' values and series names, so the chart neither unwraps, formats nor
        // interpolates per point. One pair of series names per segment. Each line has at most one
        // value per point (power two), so the arrays never grow while they fill.
        data.charge.reserveCapacity(data.points.count)
        data.temperature.reserveCapacity(data.points.count)
        data.power.reserveCapacity(2 * data.points.count)
        var series = (segment: -1, battery: "", load: "")
        for point in data.points {
            if let percent = point.percent {
                data.charge.append(HistoryChartValue(time: point.time, value: percent, segment: point.segment))
            }
            if let celsius = point.temperatureCelsius {
                data.temperature.append(HistoryChartValue(time: point.time, value: celsius, segment: point.segment))
            }
            guard point.batteryWatts != nil || point.systemLoadWatts != nil else { continue }
            if series.segment != point.segment {
                series = (point.segment, "battery-\(point.segment)", "load-\(point.segment)")
            }
            if let watts = point.batteryWatts {
                data.power.append(
                    HistoryPowerValue(
                        id: data.power.count, time: point.time, watts: watts, line: .battery, series: series.battery))
            }
            if let watts = point.systemLoadWatts {
                data.power.append(
                    HistoryPowerValue(
                        id: data.power.count, time: point.time, watts: watts, line: .systemLoad, series: series.load))
            }
        }
        return data
    }
}

/// A value of a chart line at a time.
public struct HistoryChartValue: Sendable, Equatable, Identifiable {
    public var time: Date
    public var value: Double
    /// Consecutive values share a segment; a new one starts after a gap, where the line breaks.
    public var segment: Int
    public var id: Date { time }

    public init(time: Date, value: Double, segment: Int) {
        self.time = time
        self.value = value
        self.segment = segment
    }
}

/// A value of one of the power chart's two lines.
public struct HistoryPowerValue: Sendable, Equatable, Identifiable {
    public enum Line: Sendable {
        /// Into the battery: positive while charging, negative while discharging.
        case battery
        /// What the Mac draws.
        case systemLoad
    }

    /// The position in ``HistoryChartData/power``: a battery value and a load value share a time.
    public var id: Int
    public var time: Date
    public var watts: Double
    public var line: Line
    /// The chart series, one per line and segment ("battery-0", "load-0", "battery-1"…), so each
    /// line breaks at the record's gaps.
    public var series: String

    public init(id: Int, time: Date, watts: Double, line: Line, series: String) {
        self.id = id
        self.time = time
        self.watts = watts
        self.line = line
        self.series = series
    }
}

/// A daily summary placed at noon of its day, for the health charts.
public struct HistoryDayPoint: Sendable, Equatable, Identifiable {
    public var date: Date
    public var day: HistoryDay
    public var id: String { day.day }

    public init(date: Date, day: HistoryDay) {
        self.date = date
        self.day = day
    }

    /// The summaries whose day is valid, each at noon in `timeZone`. One calendar serves them all.
    public static func points(from days: [HistoryDay], timeZone: TimeZone = .current) -> [HistoryDayPoint] {
        let calendar = HistoryDay.gregorian(in: timeZone)
        return days.compactMap { day in day.date(gregorian: calendar).map { HistoryDayPoint(date: $0, day: day) } }
    }
}

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
    /// Whether any point has a temperature, so the temperature chart has a line to draw.
    public var hasTemperature: Bool

    /// No data: what the page shows before its first load.
    public init(period: HistoryPeriod, end: Date) {
        self.period = period
        self.end = end
        points = []
        spans = []
        statistics = nil
        hasTemperature = false
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
        data.hasTemperature = data.points.contains { $0.temperatureCelsius != nil }
        return data
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

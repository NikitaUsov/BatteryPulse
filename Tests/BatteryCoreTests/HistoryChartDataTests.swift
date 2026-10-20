import Foundation
import Testing

@testable import BatteryCore

@Suite struct HistoryChartDataTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Minute samples: 30 minutes discharging, a gap of half an hour, then 20 minutes charging with
    /// no temperature for the first 5.
    private func samples() -> [HistorySample] {
        let unplugged = (0..<30).map { minute in
            HistorySample(
                time: start.addingTimeInterval(Double(minute) * 60), percent: 90 - Double(minute) / 3,
                state: .discharging, isExternalPowerConnected: false, batteryWatts: -9.5, systemLoadWatts: 9.25,
                temperatureCelsius: 30.5)
        }
        let charging = (60..<80).map { minute in
            HistorySample(
                time: start.addingTimeInterval(Double(minute) * 60), percent: 80 + Double(minute - 60) / 2,
                state: .charging, isExternalPowerConnected: true, batteryWatts: 40,
                systemLoadWatts: minute.isMultiple(of: 4) ? nil : 6.5,
                temperatureCelsius: minute < 65 ? nil : 33.25)
        }
        return unplugged + charging
    }

    @Test func dayIsTheMinuteSamplesSpansAndStatistics() {
        let samples = samples()
        let end = start.addingTimeInterval(80 * 60)
        let chart = HistoryChartData.make(samples: samples, period: .day, end: end, includesStatistics: true)
        #expect(chart.period == .day)
        #expect(chart.end == end)
        #expect(chart.points == HistoryPoint.points(from: samples))
        #expect(chart.points.count == 50)
        #expect(chart.spans == HistorySpan.spans(from: samples))
        #expect(chart.statistics == HistoryStatistics(samples: samples))
        #expect(chart.hasTemperature)
    }

    @Test func weekAveragesTenMinuteBuckets() {
        let samples = samples()
        let chart = HistoryChartData.make(samples: samples, period: .week, end: start, includesStatistics: true)
        #expect(chart.points == HistoryPoint.points(from: samples, bucket: 600))
        #expect(chart.points.map(\.segment) == [0, 0, 0, 1, 1])
        #expect(HistoryPeriod.week.length == 7 * HistoryPeriod.day.length)
        #expect(HistoryPeriod.day.bucket == nil)
    }

    @Test func devicesAndEmptyPeriodsHaveNoFigures() {
        let device = HistoryChartData.make(samples: samples(), period: .day, end: start, includesStatistics: false)
        #expect(device.statistics == nil)
        #expect(!device.points.isEmpty)
        let empty = HistoryChartData.make(samples: [], period: .week, end: start, includesStatistics: true)
        #expect(empty == HistoryChartData(period: .week, end: start))
        #expect(empty.statistics == nil && empty.points.isEmpty && empty.spans.isEmpty && !empty.hasTemperature)
    }

    @Test func noTemperatureMeansNoTemperatureChart() {
        let samples = samples().map { sample in
            var sample = sample
            sample.temperatureCelsius = nil
            return sample
        }
        #expect(
            !HistoryChartData.make(samples: samples, period: .day, end: start, includesStatistics: true).hasTemperature)
    }

    @Test func daysSitAtNoonWithOneCalendar() throws {
        let moscow = try #require(TimeZone(identifier: "Europe/Moscow"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = moscow
        let days = [
            HistoryDay(day: "2027-01-14", capacityToDesignPercent: 101.2, cycleCount: 3),
            HistoryDay(day: "garbage"),
            HistoryDay(day: "2027-01-15", capacityToDesignPercent: 101, cycleCount: 4),
        ]
        let points = HistoryDayPoint.points(from: days, timeZone: moscow)
        #expect(points.map(\.id) == ["2027-01-14", "2027-01-15"])
        #expect(points.map(\.day) == [days[0], days[2]])
        // The same dates as one day at a time.
        #expect(points.map(\.date) == [days[0], days[2]].compactMap { $0.date(calendar: calendar) })
        #expect(points.allSatisfy { calendar.component(.hour, from: $0.date) == 12 })
    }
}

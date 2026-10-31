import Foundation
import Testing

@testable import BatteryCore

@Suite struct ChartSummaryTests {
    static let utc = TimeZone(secondsFromGMT: 0)!
    static let english = BatteryFormatter(locale: Locale(identifier: "en_US"))
    static let russian = BatteryFormatter(locale: Locale(identifier: "ru_RU"))
    /// 2027-01-15 08:00 UTC, the fixtures' timestamp.
    static let end = Fixture.timestamp

    /// A week of minute samples ending at ``end``, in 8 UTC days: 8 h on battery from 100 % to
    /// 20 %, then 2 h charging back, over and over, with the Mac asleep from 01:00 to 05:00 UTC
    /// every night and no temperature in the first 20 minutes of each hour.
    static func week() -> [HistorySample] {
        let count = 7 * 24 * 60
        let start = end.addingTimeInterval(-Double(count - 1) * 60)
        return (0..<count).compactMap { minute -> HistorySample? in
            let time = start.addingTimeInterval(Double(minute) * 60)
            let hour = Int(time.timeIntervalSince1970 / 3600) % 24
            guard !(1..<5).contains(hour) else { return nil }
            let phase = minute % 600
            let isCharging = phase >= 480
            let percent = isCharging ? 20 + Double(phase - 480) * 80 / 120 : 100 - Double(phase) * 80 / 480
            return HistorySample(
                time: time, percent: percent.rounded(), state: isCharging ? .charging : .discharging,
                isExternalPowerConnected: isCharging, batteryWatts: isCharging ? 45.25 : -7.5 - Double(minute % 7),
                systemLoadWatts: isCharging ? 8.75 : 7.5 + Double(minute % 7),
                temperatureCelsius: minute % 60 < 20 ? nil : 29.8 + Double(minute % 11) / 10)
        }
    }

    /// The chart's values of each line of `summary`'s chart, as the summary must read them.
    static func lines(of kind: ChartSummary.Kind, _ data: HistoryChartData) -> [(ChartSeriesName, [(Date, Double)])] {
        switch kind {
        case .charge:
            [(.charge, data.charge.map { ($0.time, $0.value) })]
        case .power:
            [
                (.battery, data.power.filter { $0.line == .battery }.map { ($0.time, $0.watts) }),
                (.mac, data.power.filter { $0.line == .systemLoad }.map { ($0.time, $0.watts) }),
            ]
        case .temperature:
            [(.temperature, data.temperature.map { ($0.time, $0.value) })]
        case .capacity, .cycles:
            []
        }
    }

    static func summary(
        _ kind: ChartSummary.Kind, _ data: HistoryChartData, formatter: BatteryFormatter = english,
        timeZone: TimeZone = utc
    ) -> ChartSummary {
        switch kind {
        case .charge: .charge(data, formatter: formatter, timeZone: timeZone)
        case .power: .power(data, formatter: formatter, timeZone: timeZone)
        default: .temperature(data, formatter: formatter, timeZone: timeZone)
        }
    }

    /// What every summary holds against `lines`, the chart's values: a series for each line with a
    /// value, in order; at most 48 points whose stretches cover the axis in order, each read
    /// differently; the extremes, first and last value the chart's own; each point the mean of its
    /// stretch's values (the cycle count's latest) or a gap where it has none; every number as
    /// its unit reads it.
    static func expectConsistent(
        _ summary: ChartSummary, lines: [(ChartSeriesName, [(Date, Double)])], range: ClosedRange<Date>,
        formatter: BatteryFormatter, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let shown = lines.map { name, values in (name, values.filter { range.contains($0.0) }) }.filter {
            !$0.1.isEmpty
        }
        #expect(summary.series.map(\.name) == shown.map(\.0), sourceLocation: sourceLocation)
        #expect(summary.start.date == range.lowerBound, sourceLocation: sourceLocation)
        #expect(summary.end.date == range.upperBound, sourceLocation: sourceLocation)
        #expect(!summary.start.text.isEmpty && !summary.end.text.isEmpty, sourceLocation: sourceLocation)
        for (series, (name, values)) in zip(summary.series, shown) {
            let points = series.points
            #expect(!points.isEmpty && points.count <= ChartSummary.maximumPoints, sourceLocation: sourceLocation)
            #expect(series.nameKey == name.rawValue, sourceLocation: sourceLocation)
            let dates = points.map(\.time.date)
            #expect(zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 }, sourceLocation: sourceLocation)
            #expect(dates.first.map { $0 <= range.lowerBound } == true, sourceLocation: sourceLocation)
            #expect(dates.last.map { $0 <= range.upperBound } == true, sourceLocation: sourceLocation)
            let texts = points.map(\.time.text)
            #expect(Set(texts).count == texts.count && !texts.contains(""), sourceLocation: sourceLocation)

            let numbers = values.map(\.1)
            #expect(series.minimum.value.number == numbers.min(), sourceLocation: sourceLocation)
            #expect(series.maximum.value.number == numbers.max(), sourceLocation: sourceLocation)
            #expect(
                series.minimum.time.date == values.first { $0.1 == numbers.min() }?.0, sourceLocation: sourceLocation)
            #expect(
                series.maximum.time.date == values.first { $0.1 == numbers.max() }?.0, sourceLocation: sourceLocation)
            #expect(series.first.date == values.map(\.0).min(), sourceLocation: sourceLocation)
            #expect(series.last.date == values.map(\.0).max(), sourceLocation: sourceLocation)
            for extreme in [series.minimum, series.maximum] {
                #expect(
                    extreme.value.text == name.unit.text(extreme.value.number, formatter: formatter),
                    sourceLocation: sourceLocation)
            }

            for (index, point) in points.enumerated() {
                let upper = index + 1 < points.count ? points[index + 1].time.date : Date.distantFuture
                let inside = values.filter { $0.0 >= point.time.date && $0.0 < upper }
                guard let latest = inside.max(by: { $0.0 < $1.0 }) else {
                    #expect(point.value == nil, "a gap stays a gap", sourceLocation: sourceLocation)
                    continue
                }
                let mean = inside.map(\.1).reduce(0, +) / Double(inside.count)
                let expected = name == .cycles ? latest.1 : mean
                #expect(
                    abs((point.value?.number ?? .nan) - expected) < 1e-9, "\(name) at \(point.time.text)",
                    sourceLocation: sourceLocation)
                #expect(
                    point.value?.text == point.value.map { name.unit.text($0.number, formatter: formatter) },
                    sourceLocation: sourceLocation)
            }
        }
    }

    @Test func everyDayOfTheRecordGivesAnHourlySummaryOfEachChart() throws {
        let week = Self.week()
        let calendar = HistoryDay.gregorian(in: Self.utc)
        let days = Dictionary(grouping: week) { calendar.startOfDay(for: $0.time) }
        #expect(days.count == 8)
        for (_, day) in days {
            let end = try #require(day.last).time
            let samples = week.filter { $0.time > end.addingTimeInterval(-HistoryPeriod.day.length) && $0.time <= end }
            let data = HistoryChartData.make(samples: samples, period: .day, end: end, includesStatistics: true)
            for kind in [ChartSummary.Kind.charge, .power, .temperature] {
                let summary = Self.summary(kind, data)
                #expect(summary.kind == kind)
                #expect(summary.period == .day)
                #expect(summary.resolution == .hours(1))
                #expect(summary.series.count == (kind == .power ? 2 : 1))
                #expect(summary.series.allSatisfy { (24...25).contains($0.points.count) })
                Self.expectConsistent(
                    summary, lines: Self.lines(of: kind, data), range: end.addingTimeInterval(-86_400)...end,
                    formatter: Self.english)
            }
        }
    }

    @Test func aWeekReadsByDay() {
        let week = Self.week()
        let data = HistoryChartData.make(samples: week, period: .week, end: Self.end, includesStatistics: true)
        for kind in [ChartSummary.Kind.charge, .power, .temperature] {
            for formatter in [Self.english, Self.russian] {
                let summary = Self.summary(kind, data, formatter: formatter)
                #expect(summary.period == .week)
                #expect(summary.resolution == .days(1))
                #expect(summary.series.allSatisfy { $0.points.count == 8 })
                Self.expectConsistent(
                    summary, lines: Self.lines(of: kind, data),
                    range: Self.end.addingTimeInterval(-7 * 86_400)...Self.end,
                    formatter: formatter)
            }
        }
    }

    /// Each capture's battery as a day of minute samples and as a daily summary: a constant line
    /// still has its points and extremes, and a line the capture has no value for has no series.
    @Test func everyCaptureGivesASummary() throws {
        var trend: [HistoryDayPoint] = []
        let calendar = HistoryDay.gregorian(in: Self.utc)
        for (offset, fixture) in Fixture.allCases.enumerated() {
            let snapshot = try fixture.snapshot()
            let samples = (0..<180).map { minute in
                HistorySample(snapshot, at: Self.end.addingTimeInterval(Double(minute - 179) * 60))
            }
            let data = HistoryChartData.make(samples: samples, period: .day, end: Self.end, includesStatistics: true)
            for kind in [ChartSummary.Kind.charge, .power, .temperature] {
                Self.expectConsistent(
                    Self.summary(kind, data), lines: Self.lines(of: kind, data),
                    range: Self.end.addingTimeInterval(-86_400)...Self.end, formatter: Self.english)
            }
            #expect(Self.summary(.charge, data).series.isEmpty == (snapshot.chargePercent == nil), "\(fixture)")
            #expect(
                Self.summary(.temperature, data).series.isEmpty == (snapshot.temperatureCelsius == nil), "\(fixture)")
            let date = Self.end.addingTimeInterval(Double(offset - Fixture.allCases.count) * 86_400)
            let day = HistoryDay(snapshot, day: HistoryDay.key(for: date, calendar: calendar))
            trend += HistoryDayPoint.points(from: [day], timeZone: Self.utc)
        }
        let capacity = trend.compactMap { point in point.day.capacityToDesignPercent.map { (point.date, $0) } }
        let cycles = trend.compactMap { point in point.day.cycleCount.map { (point.date, Double($0)) } }
        let summaries = [
            (
                ChartSummary.capacity(trend, formatter: Self.english, timeZone: Self.utc), ChartSeriesName.capacity,
                capacity
            ),
            (ChartSummary.cycles(trend, formatter: Self.english, timeZone: Self.utc), .cycles, cycles),
        ]
        for (summary, name, values) in summaries {
            let summary = try #require(summary, "\(name)")
            #expect(summary.period == nil)
            #expect(summary.resolution == .days(1))
            let range = try #require(values.first?.0)...(try #require(values.last?.0))
            Self.expectConsistent(summary, lines: [(name, values)], range: range, formatter: Self.english)
        }
    }

    @Test func anEmptyRangeGivesASummaryWithoutSeries() {
        for period in [HistoryPeriod.day, .week] {
            let data = HistoryChartData(period: period, end: Self.end)
            for kind in [ChartSummary.Kind.charge, .power, .temperature] {
                let summary = Self.summary(kind, data)
                #expect(summary.isEmpty)
                #expect(summary.kind == kind && summary.period == period)
                #expect(summary.start.date == Self.end.addingTimeInterval(-period.length))
                #expect(summary.end.date == Self.end)
                #expect(!summary.start.text.isEmpty && summary.start.text != summary.end.text)
            }
        }
        #expect(ChartSummary.capacity([], formatter: Self.english) == nil)
        #expect(ChartSummary.cycles([], formatter: Self.english) == nil)
        let noCycles = HistoryDayPoint(date: Self.end, day: HistoryDay(day: "2027-01-15", capacityToDesignPercent: 99))
        #expect(ChartSummary.cycles([noCycles], formatter: Self.english) == nil)
        #expect(ChartSummary.capacity([noCycles], formatter: Self.english)?.series.first?.points.count == 1)
    }

    @Test func noMoreThan48Points() throws {
        // A day ending on the hour has 24 hours, one ending between hours 25; a week 8 days, or 7.
        let onTheHour = try #require(HistoryDay.gregorian(in: Self.utc).dateInterval(of: .hour, for: Self.end)).start
        for (end, period, count) in [
            (onTheHour, HistoryPeriod.day, 24), (onTheHour.addingTimeInterval(1), .day, 25),
            (onTheHour.addingTimeInterval(-8 * 3600), .week, 7), (onTheHour, .week, 8),
        ] {
            let samples = (0..<Int(period.length / 600)).map { step in
                HistorySample(time: end.addingTimeInterval(-Double(step) * 600), percent: 50, state: .discharging)
            }
            .reversed()
            let data = HistoryChartData.make(
                samples: Array(samples), period: period, end: end, includesStatistics: true)
            #expect(
                ChartSummary.charge(data, formatter: Self.english, timeZone: Self.utc).series.first?.points.count
                    == count)
        }
        // The daily summaries: a day per point up to 48 days, then as many days per point as keep
        // them to 48.
        for (count, perPoint, points) in [(2, 1, 2), (48, 1, 48), (49, 2, 25), (365, 8, 46), (3_650, 77, 48)] {
            let days = (0..<count).map { offset in
                HistoryDayPoint(
                    date: Self.end.addingTimeInterval(Double(offset) * 86_400),
                    day: HistoryDay(
                        day: "\(offset)", capacityToDesignPercent: 104 - Double(offset) / 100, cycleCount: offset))
            }
            let capacity = try #require(ChartSummary.capacity(days, formatter: Self.english, timeZone: Self.utc))
            #expect(capacity.resolution == .days(perPoint), "\(count) days")
            #expect(capacity.series.first?.points.count == points, "\(count) days")
            let values = days.compactMap { point in point.day.capacityToDesignPercent.map { (point.date, $0) } }
            Self.expectConsistent(
                capacity, lines: [(.capacity, values)], range: days[0].date...days[count - 1].date,
                formatter: Self.english)
            let cycles = try #require(ChartSummary.cycles(days, formatter: Self.english, timeZone: Self.utc))
            Self.expectConsistent(
                cycles, lines: [(.cycles, days.map { ($0.date, Double($0.day.cycleCount ?? 0)) })],
                range: days[0].date...days[count - 1].date, formatter: Self.english)
        }
        let stretches = ChartSummary.stretchStarts(
            covering: Self.end...Self.end.addingTimeInterval(1_000 * 3600), resolution: .hours(1),
            calendar: HistoryDay.gregorian(in: Self.utc))
        #expect(stretches.count == ChartSummary.maximumPoints)
        #expect(ChartSummary.stretchIndex(of: Self.end.addingTimeInterval(999 * 3600), in: stretches) == 47)
        #expect(ChartSummary.stretchIndex(of: Self.end.addingTimeInterval(-1), in: stretches) == 0)
    }

    @Test func theExtremesAreTheChartsValuesNotThePointsMeans() throws {
        // 08:00-08:59 at 50 % but one minute at 5 % at 08:30, and 100 % twice, at 08:10 and 08:40.
        let samples = (0..<60).map { minute in
            let percent: Double = minute == 30 ? 5 : [10, 40].contains(minute) ? 100 : 50
            return HistorySample(
                time: Self.end.addingTimeInterval(Double(minute) * 60), percent: percent, state: .discharging)
        }
        let end = Self.end.addingTimeInterval(59 * 60)
        let data = HistoryChartData.make(samples: samples, period: .day, end: end, includesStatistics: true)
        let series = try #require(ChartSummary.charge(data, formatter: Self.english, timeZone: Self.utc).series.first)
        #expect(series.minimum.value.number == 5)
        #expect(series.minimum.time.date == Self.end.addingTimeInterval(30 * 60))
        #expect(series.maximum.value.number == 100)
        #expect(series.maximum.time.date == Self.end.addingTimeInterval(10 * 60), "the first of two")
        let hour = try #require(series.points.last?.value)
        #expect(hour.number == Double(57 * 50 + 5 + 2 * 100) / 60)
        #expect(series.first.date == Self.end && series.last.date == end)
    }

    @Test func aGapStaysAGapAndAZeroStaysAZero() throws {
        // On the adapter at a full charge from 08:00 to 09:59 (0 W into the battery), asleep until
        // 13:00, then on battery to 13:59.
        let held = (0..<120).map { minute in
            HistorySample(
                time: Self.end.addingTimeInterval(Double(minute) * 60), percent: 100, state: .charged,
                isExternalPowerConnected: true, batteryWatts: 0, systemLoadWatts: 6)
        }
        let unplugged = (300..<360).map { minute in
            HistorySample(
                time: Self.end.addingTimeInterval(Double(minute) * 60), percent: 99, state: .discharging,
                isExternalPowerConnected: false, batteryWatts: -6, systemLoadWatts: 6)
        }
        let end = Self.end.addingTimeInterval(359 * 60)
        let data = HistoryChartData.make(samples: held + unplugged, period: .day, end: end, includesStatistics: true)
        let power = ChartSummary.power(data, formatter: Self.english, timeZone: Self.utc)
        let battery = try #require(power.series.first)
        #expect(battery.name == .battery)
        // The record's 24 hours end at 13:59, so they begin with the hour from 13:00 the day before.
        let byHour = Dictionary(
            uniqueKeysWithValues: battery.points.suffix(7).map {
                (Int($0.time.date.timeIntervalSince(Self.end) / 3600), $0)
            })
        #expect(byHour[0]?.value?.number == 0, "a measured 0 W is a value")
        #expect(byHour[1]?.value?.number == 0)
        for hour in 2...4 { #expect(byHour[hour]?.value == nil, "asleep at \(hour + 8):00") }
        #expect(byHour[5]?.value?.number == -6)
        #expect(battery.points.dropLast(6).allSatisfy { $0.value == nil }, "nothing recorded before 08:00")
        #expect(battery.points.count == 25)
        Self.expectConsistent(
            power, lines: Self.lines(of: .power, data), range: end.addingTimeInterval(-86_400)...end,
            formatter: Self.english)
    }

    @Test func aDeviceHasNoMacLine() {
        let samples = (0..<30).map { minute in
            HistorySample(
                time: Self.end.addingTimeInterval(Double(minute) * 60), percent: 40 + Double(minute), state: .charging,
                batteryWatts: 12.5)
        }
        let data = HistoryChartData.make(samples: samples, period: .day, end: Self.end, includesStatistics: false)
        #expect(ChartSummary.power(data, formatter: Self.english, timeZone: Self.utc).series.map(\.name) == [.battery])
    }

    @Test func numbersReadAsTheChartsShowThem() {
        for formatter in [Self.english, Self.russian] {
            #expect(ChartSeriesName.charge.unit.text(91.4, formatter: formatter) == formatter.percent(91.4))
            #expect(ChartSeriesName.battery.unit.text(40, formatter: formatter) == formatter.watts(40, signed: true))
            #expect(ChartSeriesName.mac.unit.text(7.5, formatter: formatter) == formatter.watts(7.5))
            #expect(ChartSeriesName.temperature.unit.text(31.24, formatter: formatter) == formatter.celsius(31.24))
            #expect(
                ChartSeriesName.capacity.unit.text(104.27, formatter: formatter)
                    == formatter.percent(104.27, fractionDigits: 1))
            // The Health page's `cycles.formatted()`.
            #expect(
                ChartSeriesName.cycles.unit.text(1_234, formatter: formatter)
                    == 1_234.formatted(.number.locale(formatter.locale)))
        }
        #expect(ChartSeriesName.battery.unit.text(40, formatter: Self.english) == "+40.0\u{00A0}W")
        #expect(ChartSeriesName.battery.unit.text(-9.5, formatter: Self.english) == "\u{2212}9.5\u{00A0}W")
        #expect(ChartSeriesName.mac.unit.text(7.5, formatter: Self.english) == "7.5\u{00A0}W")
    }

    @Test func timesReadByTheirStretchInTheGivenTimeZone() throws {
        // 2027-01-15 08:00 UTC is 11:00 in UTC+3 and 13:30 in UTC+5:30.
        let plus3 = try #require(TimeZone(secondsFromGMT: 3 * 3600))
        let india = try #require(TimeZone(secondsFromGMT: 5 * 3600 + 1800))
        let samples = (0..<120).map { minute in
            HistorySample(time: Self.end.addingTimeInterval(Double(minute) * 60), percent: 50, state: .discharging)
        }
        let end = Self.end.addingTimeInterval(119 * 60)
        let day = HistoryChartData.make(samples: samples, period: .day, end: end, includesStatistics: true)
        let moscow = try #require(
            ChartSummary.charge(day, formatter: Self.russian, timeZone: plus3).series.first?.points.suffix(2))
        #expect(moscow.map { $0.time.text.contains("11:00") } == [true, false])
        #expect(moscow.map { $0.time.text.contains("12:00") } == [false, true])
        #expect(moscow.allSatisfy { $0.value?.number == 50 })
        // Hours start on the local hour, days at local midnight.
        let hours = try #require(ChartSummary.charge(day, formatter: Self.english, timeZone: india).series.first)
        #expect(hours.points.allSatisfy { Int($0.time.date.timeIntervalSince1970) % 3600 == 1800 })
        let week = HistoryChartData.make(samples: samples, period: .week, end: end, includesStatistics: true)
        let days = try #require(ChartSummary.charge(week, formatter: Self.english, timeZone: india).series.first)
        #expect(days.points.allSatisfy { (Int($0.time.date.timeIntervalSince1970) + 19_800) % 86_400 == 0 })
        #expect(days.points.last?.time.text.contains("15") == true, "January 15 in India")
        // A trend's points are dates, with the year.
        let trend = try #require(
            ChartSummary.capacity(
                HistoryDayPoint.points(
                    from: [HistoryDay(day: "2026-12-31", capacityToDesignPercent: 100)], timeZone: plus3),
                formatter: Self.russian, timeZone: plus3))
        #expect(trend.series.first?.points.first?.time.text.contains("2026") == true)
        #expect(trend.series.first?.points.first?.time.text.contains("31") == true)
    }

    /// The series' names are keys the charts already use, so the app's descriptors reuse their
    /// translations.
    @Test func seriesNamesAreCatalogKeys() throws {
        struct Catalog: Decodable {
            struct Entry: Decodable {
                struct Localization: Decodable {
                    struct StringUnit: Decodable { var value: String }
                    var stringUnit: StringUnit
                }
                var localizations: [String: Localization]?
            }
            var strings: [String: Entry]
        }
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try JSONDecoder().decode(
            Catalog.self, from: Data(contentsOf: repository.appendingPathComponent("Resources/Localizable.xcstrings")))
        for name in ChartSeriesName.allCases {
            #expect(catalog.strings[name.key]?.localizations?["ru"]?.stringUnit.value.isEmpty == false, "\(name)")
        }
    }
}

import Foundation
import Testing

@testable import BatteryCore

@Suite struct HistoryTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func sample(
        _ minute: Double, _ percent: Double, _ state: ChargeState = .discharging, watts: Double? = -10
    ) -> HistorySample {
        HistorySample(
            time: start.addingTimeInterval(minute * 60), percent: percent, state: state,
            isExternalPowerConnected: state != .discharging, batteryWatts: watts, systemLoadWatts: 8)
    }

    @Test func samplesUseCompactKeysAndWholeSeconds() throws {
        var s = sample(0, 78.0)
        s.time = start.addingTimeInterval(0.4)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(s), as: UTF8.self)
        #expect(json == #"{"b":-10,"l":8,"p":78,"s":"discharging","t":1800000000,"x":false}"#)
        let decoded = try JSONDecoder().decode(HistorySample.self, from: Data(json.utf8))
        #expect(decoded.time == start)
        #expect(decoded.percent == 78)
    }

    @Test func recordsAboutOnceAMinuteAndOnChanges() {
        let first = sample(0, 80)
        #expect(HistoryPolicy.shouldRecord(first, after: nil))
        #expect(!HistoryPolicy.shouldRecord(sample(0.5, 80), after: first))
        #expect(HistoryPolicy.shouldRecord(sample(1, 80), after: first))
        #expect(HistoryPolicy.shouldRecord(sample(0.5, 80, .charging), after: first), "plugged in")
        #expect(!HistoryPolicy.shouldRecord(sample(0.1, 80, .charging), after: first), "not within 10 s")
        #expect(HistoryPolicy.shouldRecord(sample(-5, 80), after: first), "clock moved back")
    }

    @Test func statisticsOnBattery() throws {
        // One hour on battery, 10 % gone at 10 W, then charging, a gap, and charging again.
        var samples = (0...60).map { sample(Double($0), 90 - Double($0) / 6) }
        samples.append(sample(61, 80, .charging, watts: 30))
        samples.append(sample(62, 80.5, .charging, watts: 30))
        samples.append(sample(63, 80.5, .discharging))
        samples.append(sample(200, 70, .discharging))  // after sleep: not counted
        samples.append(sample(201, 70, .charging, watts: 30))
        let stats = HistoryStatistics(samples: samples)
        #expect(stats.timeOnBattery == 3600)
        #expect(abs(try #require(stats.averageDrainPercentPerHour) - 10) < 0.001)
        #expect(abs(stats.energyFromBatteryWattHours - 10) < 0.001)
        #expect(stats.chargingSessions == 2)
        #expect(HistoryStatistics(samples: Array(samples.prefix(5))).averageDrainPercentPerHour == nil, "too short")
    }

    @Test func chartPointsAverageBucketsAndBreakAtGaps() {
        let samples = (0..<30).map { sample(Double($0), 90) } + (60..<70).map { sample(Double($0), 80) }
        let minute = HistoryPoint.points(from: samples)
        #expect(minute.count == 40)
        #expect(Set(minute.map(\.segment)) == [0, 1])
        let tenMinute = HistoryPoint.points(from: samples, bucket: 600)
        #expect(tenMinute.count == 4)
        #expect(tenMinute.map(\.segment) == [0, 0, 0, 1], "buckets alone never split the line")
        #expect(tenMinute.last?.percent == 80)
    }

    @Test func dayKeysAndDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Moscow"))
        // 1_800_000_000 is 2027-01-15 08:00 UTC, 11:00 in Moscow.
        #expect(HistoryDay.key(for: start, calendar: calendar) == "2027-01-15")
        let noon = try #require(HistoryDay(day: "2027-01-15").date(calendar: calendar))
        #expect(calendar.component(.hour, from: noon) == 12)
    }

    @Test func storeAppendsTrimsAndSummarises() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)

        #expect(try await store.record(sample(0, 90)))
        #expect(try await store.record(sample(0.2, 90)) == false)
        #expect(try await store.record(sample(1, 89.8)))
        #expect(try await store.samples(since: start).count == 2)

        // A fresh store reads what is on disk, and skips a torn last line.
        let samplesFile = directory.appendingPathComponent("samples.jsonl")
        let handle = try FileHandle(forWritingTo: samplesFile)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"t":18000"#.utf8))
        try handle.close()
        let reopened = HistoryStore(directory: directory)
        #expect(try await reopened.samples(since: start).count == 2)

        // Eleven days later the old samples are trimmed away.
        #expect(try await reopened.record(sample(11 * 24 * 60, 50)))
        #expect(try await reopened.samples(since: .distantPast).count == 1)

        try await reopened.record(HistoryDay(day: "2027-01-15", healthPercent: 100, cycleCount: 48))
        try await reopened.record(HistoryDay(day: "2027-01-15", healthPercent: 100, cycleCount: 49))
        try await reopened.record(HistoryDay(day: "2027-01-16", healthPercent: 99.9, cycleCount: 49))
        let days = try await HistoryStore(directory: directory).dailySummaries()
        #expect(days.map(\.day) == ["2027-01-15", "2027-01-16"])
        #expect(days.first?.cycleCount == 49, "the later line for a day wins")

        try await reopened.clear()
        #expect(try await reopened.samples(since: .distantPast).isEmpty)
        #expect(try await reopened.dailySummaries().isEmpty)
    }
}

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
        // 10 Wh in the hour, plus half a minute at 10 W on each of the three minutes where the
        // power crosses zero.
        #expect(abs(stats.energyFromBatteryWattHours - 10.25) < 0.001)
        #expect(stats.chargingSessions == 2)
        #expect(HistoryStatistics(samples: Array(samples.prefix(5))).averageDrainPercentPerHour == nil, "too short")
    }

    @Test func drainNeedsEnoughChargeUsed() {
        // An hour on battery that used only 2 points says nothing reliable.
        let samples = (0...60).map { sample(Double($0), 90 - Double($0) / 30) }
        #expect(HistoryStatistics(samples: samples).averageDrainPercentPerHour == nil)
    }

    @Test func heldChargeAndShortUnplugsAreOneSession() {
        let samples = [
            sample(0, 50),
            sample(1, 50, .charging, watts: 30),  // plugged in: one session
            sample(2, 60, .notCharging, watts: 0),  // held by Optimized Charging
            sample(3, 60, .charging, watts: 30),  // resumed: same session
            sample(3.5, 60),  // unplugged for a minute...
            sample(4.5, 60, .charging, watts: 30),  // ...and back: same session
            sample(10, 70),
            sample(15, 69, .charging, watts: 30),  // a new session
        ]
        #expect(HistoryStatistics(samples: samples).chargingSessions == 2)
    }

    @Test func spansFollowThePowerAdapterAndStopAtGaps() {
        let samples = [
            sample(0, 50), sample(1, 50, .charging, watts: 30), sample(2, 51, .charging, watts: 30),
            sample(3, 52, .notCharging, watts: 0), sample(4, 52, .notCharging, watts: 0), sample(5, 52),
            sample(30, 51, .charging, watts: 30), sample(31, 52, .charging, watts: 30),
        ]
        let spans = HistorySpan.spans(from: samples)
        func at(_ minute: Double) -> Date { start.addingTimeInterval(minute * 60) }
        #expect(
            spans == [
                HistorySpan(start: at(1), end: at(3), kind: .charging),
                HistorySpan(start: at(3), end: at(5), kind: .pluggedIn),
                HistorySpan(start: at(30), end: at(31), kind: .charging),
            ])
    }

    @Test func nearestPointUsesBinarySearch() {
        let points = HistoryPoint.points(from: (0..<10).map { sample(Double($0), 90) })
        #expect(
            HistoryPoint.nearest(in: points, to: start.addingTimeInterval(4.4 * 60))?.time
                == start.addingTimeInterval(240))
        #expect(HistoryPoint.nearest(in: points, to: start.addingTimeInterval(-100))?.time == start)
        #expect(
            HistoryPoint.nearest(in: points, to: start.addingTimeInterval(9999))?.time == start.addingTimeInterval(540))
        #expect(HistoryPoint.nearest(in: [], to: start) == nil)
    }

    @Test func eventsAlwaysRecordAndRoundTrip() throws {
        let first = sample(0, 80)
        var wake = sample(0.05, 80)
        wake.event = .wake
        wake.remainingMAh = 4514
        wake.fullChargeMAh = 5862
        #expect(HistoryPolicy.shouldRecord(wake, after: first))
        let decoded = try JSONDecoder().decode(HistorySample.self, from: JSONEncoder().encode(wake))
        #expect(decoded.event == .wake)
        #expect(decoded.remainingMAh == 4514)
        // An event this version doesn't know is ignored, not fatal.
        let future = #"{"t":1800000000,"e":"teleport","s":"charging"}"#
        #expect(try JSONDecoder().decode(HistorySample.self, from: Data(future.utf8)).event == nil)
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

    @Test func storeFilesSamplesByDayTrimsAndSummarises() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        // The samples are dated 2027; let the store's clock agree.
        let store = HistoryStore(directory: directory, now: { .distantFuture })

        #expect(try await store.record(sample(0, 90)))
        #expect(try await store.record(sample(0.2, 90)) == false)
        #expect(try await store.record(sample(1, 89.8)))
        #expect(try await store.samples(since: start).count == 2)
        // 1_800_000_000 is 2027-01-15 08:00 UTC.
        let dayFile = directory.appendingPathComponent("samples/2027-01-15.jsonl")
        #expect(FileManager.default.fileExists(atPath: dayFile.path))

        // A fresh store reads what is on disk, and skips a torn last line.
        let handle = try FileHandle(forWritingTo: dayFile)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"t":18000"#.utf8))
        try handle.close()
        let reopened = HistoryStore(directory: directory, now: { .distantFuture })
        #expect(try await reopened.samples(since: start).count == 2)
        #expect(try await reopened.record(sample(1.2, 89.8)) == false, "remembers the last sample")

        // A day later: a second file, and a range reads only what it needs.
        #expect(try await reopened.record(sample(24 * 60, 60)))
        #expect(try await reopened.samples(from: start.addingTimeInterval(23 * 3600)).count == 1)
        #expect(try await reopened.samples(from: start, to: start.addingTimeInterval(3600)).count == 2)

        // Twelve more days of records: the first day's file goes, eleven days' files stay.
        for day in 2...12 { #expect(try await reopened.record(sample(Double(day) * 24 * 60, 50))) }
        #expect(!FileManager.default.fileExists(atPath: dayFile.path))
        let files = try FileManager.default.contentsOfDirectory(
            atPath: directory.appendingPathComponent("samples").path)
        #expect(files.count == 11)

        try await reopened.clear()
        #expect(try await reopened.samples(since: .distantPast).isEmpty)
        #expect(try await reopened.dailySummaries().isEmpty)
    }

    @Test func aClockSetAheadDoesNotDeleteHistory() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        // The store's clock moves with the samples, as in the app.
        let store = HistoryStore(directory: directory, now: { .distantFuture })
        for day in 0..<5 { #expect(try await store.record(sample(Double(day) * 24 * 60, 80))) }
        // The Mac's date is set 40 days ahead for a moment.
        #expect(try await store.record(sample(44 * 24 * 60, 79)))
        #expect(try await store.samples(since: .distantPast).count == 6)
        // After the clock is set back and the app relaunched, the stray future sample isn't taken
        // as the last one.
        let today = start.addingTimeInterval(4 * 24 * 60 * 60)
        let reopened = HistoryStore(directory: directory, now: { today })
        #expect(
            try await reopened.record(sample(4 * 24 * 60 + 0.5, 80)) == false, "within a minute of the real last sample"
        )
    }

    @Test func dayKeysAreGregorianWhateverTheUserCalendar() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = try #require(TimeZone(identifier: "Asia/Bangkok"))
        #expect(HistoryDay.key(for: start, calendar: buddhist) == "2027-01-15")
        let noon = try #require(HistoryDay(day: "2027-01-15").date(calendar: buddhist))
        #expect(HistoryDay.key(for: noon, calendar: buddhist) == "2027-01-15")
    }

    @Test func dailySummariesAreCompactedAndWrittenSparingly() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        func stored() async throws -> [HistoryDay] { try await HistoryStore(directory: directory).dailySummaries() }

        try await store.record(
            HistoryDay(day: "2027-01-15", healthPercent: 100, fullChargeCapacityMAh: 5862), at: start)
        #expect(try await stored().first?.fullChargeCapacityMAh == 5862, "a new day is written at once")
        // A few mAh later: kept in memory until the hour is up.
        try await store.record(
            HistoryDay(day: "2027-01-15", healthPercent: 100, fullChargeCapacityMAh: 5866),
            at: start.addingTimeInterval(60))
        #expect(try await stored().first?.fullChargeCapacityMAh == 5862)
        #expect(try await store.dailySummaries().first?.fullChargeCapacityMAh == 5866)
        // A cycle is written at once.
        try await store.record(
            HistoryDay(day: "2027-01-15", healthPercent: 100, fullChargeCapacityMAh: 5866, cycleCount: 49),
            at: start.addingTimeInterval(120))
        #expect(try await stored().first?.cycleCount == 49)
        try await store.record(HistoryDay(day: "2027-01-16", healthPercent: 99.9, cycleCount: 49), at: start)
        let days = try await stored()
        #expect(days.map(\.day) == ["2027-01-15", "2027-01-16"])
        // One line per day on disk.
        let lines = try String(contentsOf: directory.appendingPathComponent("days.jsonl"), encoding: .utf8)
        #expect(lines.split(separator: "\n").count == 2)
        try await store.flush()
    }

    @Test func legacySingleFileIsSplitByDay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        let lines = try [sample(0, 90), sample(24 * 60, 80)].map {
            String(decoding: try encoder.encode($0), as: UTF8.self)
        }
        try (lines.joined(separator: "\n") + "\n").write(
            to: directory.appendingPathComponent("samples.jsonl"), atomically: true, encoding: .utf8)
        let store = HistoryStore(directory: directory)
        #expect(try await store.samples(since: .distantPast).count == 2)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("samples.jsonl").path))
        #expect(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("samples/2027-01-16.jsonl").path))
    }
}

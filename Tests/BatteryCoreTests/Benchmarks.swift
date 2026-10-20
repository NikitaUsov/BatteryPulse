import BatteryCore
import Foundation
import Testing

/// Micro-benchmarks B1–B6 (playbook §2.5): reported, never asserted, and off unless `BP_BENCH=1`:
///
///     BP_BENCH=1 swift test -c release --filter Benchmarks
///
/// Each workload runs once to warm up, then ``runs`` times on `ContinuousClock`, and prints one
/// line, `bench <id> <workload> median_ms=<median> runs=15`. Testable imports change the
/// optimization a little, so compare only a before and an after on the same machine and
/// toolchain. The workloads exist at 0.6.0 too, so the file ran on the baseline branch; since
/// WP-5, B4's `raw.display` and B5's `raw.filter.joined` measure 0.6.1's Raw Data display rows.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["BP_BENCH"] == "1"))
struct Benchmarks {
    static let runs = 15

    // MARK: B1–B6

    /// B1: a capture's dictionaries, from the property list's objects through `PropertyValue` to
    /// the snapshot, per real fixture.
    @Test func b1ParseFixtures() throws {
        for fixture in Fixture.allCases where fixture.rawValue.hasPrefix("m5-macos27-") {
            let root = try Self.propertyList(fixture)
            let timing = Self.time {
                PropertyValue.dictionary(fromAny: root).map {
                    BatteryReading(rawCapture: $0, timestamp: Fixture.timestamp)
                }
            }
            Self.report("B1", "parse/\(fixture.rawValue)", timing.median)
        }
    }

    /// B2: a week of history from disk, 10,080 minute samples in 8 day files: a fresh store's first
    /// load (cold), its second (warm), and a third after today's file gained a line, as it does
    /// every minute in the app (tail).
    @Test func b2HistoryStoreWeek() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let samples = Self.week()
        try Self.writeSamples(samples, to: directory)
        let start = try #require(samples.first).time
        let end = try #require(samples.last).time
        let today = directory.appendingPathComponent("samples/2027-01-15.jsonl")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var next = try #require(samples.last)
        next.time = end.addingTimeInterval(60)
        let line = try encoder.encode(next) + Data([0x0A])
        var cold: [Duration] = []
        var warm: [Duration] = []
        var tail: [Duration] = []
        let clock = ContinuousClock()
        // Run 0 warms up.
        for run in 0...Self.runs {
            let store = HistoryStore(directory: directory, now: { end })
            var begin = clock.now
            let first = try await store.samples(from: start)
            let coldTime = clock.now - begin
            begin = clock.now
            let second = try await store.samples(from: start)
            let warmTime = clock.now - begin
            let handle = try FileHandle(forUpdating: today)
            let size = try handle.seekToEnd()
            try handle.write(contentsOf: line)
            begin = clock.now
            let third = try await store.samples(from: start)
            let tailTime = clock.now - begin
            try handle.truncate(atOffset: size)
            try handle.close()
            #expect(first.count == samples.count && second.count == samples.count)
            #expect(third.count == samples.count + 1)
            guard run > 0 else { continue }
            cold.append(coldTime)
            warm.append(warmTime)
            tail.append(tailTime)
        }
        Self.report("B2", "history.samples.7d.cold", Self.median(of: cold))
        Self.report("B2", "history.samples.7d.warm", Self.median(of: warm))
        Self.report("B2", "history.samples.7d.tail", Self.median(of: tail))
    }

    /// B3: what the History page computes from the samples: chart points, spans and statistics, for
    /// a day of minute samples and a week in ten-minute buckets.
    @Test func b3HistoryChartData() {
        let week = Self.week()
        let periods: [(name: String, samples: [HistorySample], bucket: TimeInterval?)] = [
            ("24h", Array(week.suffix(24 * 60)), nil),
            ("7d", week, 10 * 60),
        ]
        for period in periods {
            let timing = Self.time {
                (
                    HistoryPoint.points(from: period.samples, bucket: period.bucket),
                    HistorySpan.spans(from: period.samples),
                    HistoryStatistics(samples: period.samples)
                )
            }
            Self.report("B3", "history.chart.\(period.name)", timing.median)
        }
    }

    /// B4: the Raw Data table for the fixture with the most rows: the redacted capture's sections
    /// with the text each row shows that BatteryCore builds (`raw.sections`, the 0.6.0 workload),
    /// and the display rows the page builds once per reading, off the main actor: every cell's
    /// text, the decoded values formatted and the summaries looked up, plus the search text
    /// (`raw.display`).
    @Test func b4RawSections() throws {
        let reading = try Self.largestRawCapture()
        let timing = Self.time {
            RawSection.sections(for: reading.redactedRawCapture).flatMap(\.rows).map {
                ($0.path, $0.value, $0.info?.summary)
            }
        }
        Self.report("B4", "raw.sections", timing.median)
        let display = Self.time {
            RawDisplaySection.sections(
                for: reading.redactedRawCapture, decoded: RawDisplayTests.decodedText,
                summary: RawDisplayTests.localizedSummary)
        }
        Self.report("B4", "raw.display", display.median)
    }

    /// B5: Raw Data's filter, a six-letter query over every row of that fixture: the five-way OR
    /// that 0.6.0 ran per row, against ``RawDisplaySection/filter(_:by:)`` over the display rows.
    @Test func b5RawFilter() throws {
        let capture = try Self.largestRawCapture().redactedRawCapture
        let rows = RawSection.sections(for: capture).flatMap(\.rows)
        let display = RawDisplaySection.sections(
            for: capture, decoded: RawDisplayTests.decodedText, summary: RawDisplayTests.localizedSummary)
        let query = "charge"
        let old = Self.time { rows.filter { RawDisplayTests.matchesFiveWays($0, query) }.count }
        let new = Self.time { RawDisplaySection.filter(display, by: query).reduce(0) { $0 + $1.rows.count } }
        // The same rows.
        #expect(old.last == new.last)
        Self.report("B5", "raw.filter.fiveWay", old.median)
        Self.report("B5", "raw.filter.joined", new.median)
    }

    /// B6: `bpulse`'s text and JSON output per fixture.
    @Test func b6Report() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        for fixture in Fixture.allCases {
            let snapshot = try fixture.snapshot()
            Self.report("B6", "report.text/\(fixture.rawValue)", Self.time { BatteryReport.text(for: snapshot) }.median)
            Self.report("B6", "report.json/\(fixture.rawValue)", try Self.time { try encoder.encode(snapshot) }.median)
        }
    }

    // MARK: Timing

    /// The median of ``runs`` timed calls of `body`, after one untimed call, and the last result.
    /// The results are kept until the end, so the optimizer can't drop the work.
    static func time<T>(_ body: () throws -> T) rethrows -> (median: Duration, last: T) {
        var results = [try body()]
        var times: [Duration] = []
        let clock = ContinuousClock()
        for _ in 0..<runs {
            let begin = clock.now
            let result = try body()
            times.append(clock.now - begin)
            results.append(result)
        }
        return withExtendedLifetime(results) { (median(of: times), results[results.count - 1]) }
    }

    static func median(of times: [Duration]) -> Duration {
        times.sorted()[times.count / 2]
    }

    static func report(_ id: String, _ workload: String, _ median: Duration) {
        let (seconds, attoseconds) = median.components
        let milliseconds = Double(seconds) * 1000 + Double(attoseconds) / 1e15
        print("bench \(id) \(workload) median_ms=\(String(format: "%.3f", milliseconds)) runs=\(runs)")
    }

    // MARK: Workloads

    /// The fixture's property list objects, before any conversion.
    static func propertyList(_ fixture: Fixture) throws -> Any {
        let url = try #require(
            Bundle.module.url(forResource: fixture.rawValue, withExtension: "plist", subdirectory: "Fixtures"))
        return try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
    }

    /// The Mac fixture whose Raw Data table has the most rows.
    static func largestRawCapture() throws -> BatteryReading {
        let readings = try Fixture.allCases.map { try $0.reading() }
        func rowCount(_ reading: BatteryReading) -> Int {
            RawSection.sections(for: reading.redactedRawCapture).reduce(0) { $0 + $1.rows.count }
        }
        return try #require(readings.max { rowCount($0) < rowCount($1) })
    }

    /// A week of minute samples ending at the fixtures' timestamp (2027-01-15 08:00 UTC), so they
    /// fall into 8 UTC days: 8 h on battery from 100 % to 20 %, then 2 h charging back, over and
    /// over.
    static func week() -> [HistorySample] {
        let count = 7 * 24 * 60
        let start = Fixture.timestamp.addingTimeInterval(-Double(count - 1) * 60)
        return (0..<count).map { minute in
            let phase = minute % 600
            let isCharging = phase >= 480
            let percent = isCharging ? 20 + Double(phase - 480) * 80 / 120 : 100 - Double(phase) * 80 / 480
            return HistorySample(
                time: start.addingTimeInterval(Double(minute) * 60), event: minute == 0 ? .launch : nil,
                percent: percent.rounded(), state: isCharging ? .charging : .discharging,
                isExternalPowerConnected: isCharging, batteryWatts: isCharging ? 45.25 : -7.5,
                systemLoadWatts: isCharging ? 8.75 : 7.5, temperatureCelsius: isCharging ? 33.4 : 29.8,
                remainingMAh: Int(percent * 45), fullChargeMAh: 4_500)
        }
    }

    /// Writes `samples` the way ``HistoryStore`` files them: JSON Lines with sorted keys, one file
    /// per UTC day under `samples/`.
    static func writeSamples(_ samples: [HistorySample], to directory: URL) throws {
        let folder = directory.appendingPathComponent("samples")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let days = Dictionary(grouping: samples) { HistoryDay.key(for: $0.time, calendar: calendar) }
        #expect(days.count == 8)
        for (day, group) in days {
            var data = Data()
            for sample in group {
                data.append(try encoder.encode(sample))
                data.append(0x0A)
            }
            try data.write(to: folder.appendingPathComponent(day + ".jsonl"))
        }
    }
}

import Foundation
import Testing

@testable import BatteryCore

/// The store's work counts (playbook C1): what reaches the disk and what gets decoded, never
/// timing. 1_800_000_000 is 2027-01-15 08:00 UTC.
@Suite struct HistoryStoreTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    private func sample(_ minute: Double, _ percent: Double, _ state: ChargeState = .discharging) -> HistorySample {
        HistorySample(
            time: start.addingTimeInterval(minute * 60), percent: percent, state: state,
            isExternalPowerConnected: state != .discharging, batteryWatts: -10, systemLoadWatts: 8)
    }

    /// A store whose clock agrees with the samples' 2027 dates.
    private func store() -> HistoryStore {
        HistoryStore(directory: directory, now: { .distantFuture })
    }

    private func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func aSampleIsOneAppendAndTheDaySummaryIsRewrittenSparingly() async throws {
        defer { removeDirectory() }
        let store = store()
        // Two hours of the recorder's minute ticks: a sample, then the day's summary, whose
        // full-charge capacity drifts by a few mAh.
        for minute in 0..<120 {
            #expect(try await store.record(sample(Double(minute), 90 - Double(minute) / 10)))
            let day = HistoryDay(
                day: "2027-01-15", healthPercent: 100, fullChargeCapacityMAh: 5_860 + minute % 7, cycleCount: 48)
            try await store.record(day, at: start.addingTimeInterval(Double(minute) * 60))
        }
        let activity = await store.activity
        #expect(activity.appends == 120)
        #expect(activity.daysWrites <= 2)
        #expect(activity.legacyChecks == 1)
        // A sample the policy rejects does nothing on disk.
        #expect(try await store.record(sample(119.5, 78)) == false)
        #expect(await store.activity == activity)
        let lines = try String(
            contentsOf: directory.appendingPathComponent("samples/2027-01-15.jsonl"), encoding: .utf8)
        #expect(lines.split(separator: "\n").count == 120)
    }

    // MARK: The decode cache

    /// What a fresh store, which decodes every file, reads from the same folder.
    private func onDisk() async throws -> [HistorySample] {
        try await store().samples(from: .distantPast)
    }

    @Test func aClosedDayIsDecodedOnceAcrossLoads() async throws {
        defer { removeDirectory() }
        let store = store()
        let minutes: [Double] = [0, 1, 2, 24 * 60, 24 * 60 + 1, 48 * 60]
        for minute in minutes { try await store.record(sample(minute, 80)) }
        let reader = self.store()
        let first = try await reader.samples(from: .distantPast)
        #expect(first.count == 6)
        #expect(await reader.activity.decodedSampleLines == 6)
        let second = try await reader.samples(from: .distantPast)
        #expect(second == first)
        #expect(await reader.activity.decodedSampleLines == 6, "nothing changed, nothing decoded")
        // A range reads only its days, from the cache.
        #expect(try await reader.samples(from: start.addingTimeInterval(24 * 3600)).count == 3)
        #expect(await reader.activity.decodedSampleLines == 6)
    }

    @Test func todaysFileIsReadFromItsLastOffset() async throws {
        defer { removeDirectory() }
        let store = store()
        for minute in 0..<5 { try await store.record(sample(Double(minute), 80)) }
        #expect(try await store.samples(from: .distantPast).count == 5)
        let decoded = await store.activity.decodedSampleLines
        try await store.record(sample(5, 79))
        #expect(try await store.samples(from: .distantPast) == onDisk())
        #expect(await store.activity.decodedSampleLines == decoded + 1, "only the new line")

        // A write cut short leaves a torn line; the next sample starts on a line of its own.
        let today = directory.appendingPathComponent("samples/2027-01-15.jsonl")
        let handle = try FileHandle(forWritingTo: today)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"p":79,"s":"disch"#.utf8))
        try handle.close()
        #expect(try await store.samples(from: .distantPast).count == 6)
        try await store.record(sample(6, 79))
        let loaded = try await store.samples(from: .distantPast)
        #expect(loaded.count == 7)
        #expect(loaded == (try await onDisk()))
    }

    @Test func anUnterminatedLastLineIsReadAgainOnceItEnds() async throws {
        defer { removeDirectory() }
        let store = store()
        try await store.record(sample(0, 80))
        // The line of a complete sample whose newline never reached the disk.
        let today = directory.appendingPathComponent("samples/2027-01-15.jsonl")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let handle = try FileHandle(forWritingTo: today)
        try handle.seekToEnd()
        try handle.write(contentsOf: try encoder.encode(sample(1, 79)))
        try handle.close()
        #expect(try await store.samples(from: .distantPast).map(\.percent) == [80, 79])
        try await store.record(sample(2, 78))
        #expect(try await store.samples(from: .distantPast).map(\.percent) == [80, 79, 78])
        #expect(try await store.samples(from: .distantPast) == onDisk())
    }

    @Test func clearHistoryEmptiesTheCache() async throws {
        defer { removeDirectory() }
        let store = store()
        try await store.record(sample(0, 80))
        #expect(try await store.samples(from: .distantPast).map(\.percent) == [80])
        try await store.clear()
        // The same day's file again, with a line of the same length.
        try await store.record(sample(1, 70))
        #expect(try await store.samples(from: .distantPast).map(\.percent) == [70])
    }

    @Test func pruningEmptiesTheCacheOfTheDaysItDeletes() async throws {
        defer { removeDirectory() }
        let store = store()
        try await store.record(sample(0, 80))
        #expect(try await store.samples(from: .distantPast).map(\.percent) == [80])
        // Twelve days later, the first day's file is gone.
        for day in 1...12 { try await store.record(sample(Double(day) * 24 * 60, 50)) }
        let firstDay = directory.appendingPathComponent("samples/2027-01-15.jsonl")
        #expect(!FileManager.default.fileExists(atPath: firstDay.path))
        // The clock is set back: that day's file comes back with a line of the same length.
        try await store.record(sample(1, 70))
        let loaded = try await store.samples(from: .distantPast)
        #expect(loaded.first?.percent == 70)
        #expect(loaded == (try await onDisk()))
    }

    @Test func theDayRolloverKeepsClosedDaysAndReadsTheNewOne() async throws {
        defer { removeDirectory() }
        let store = store()
        // 23:57 to 23:59 UTC, then past midnight.
        let lastMinutes = (16 * 60 - 3)..<(16 * 60)
        for minute in lastMinutes { try await store.record(sample(Double(minute), 60)) }
        #expect(try await store.samples(from: .distantPast).count == 3)
        let decoded = await store.activity.decodedSampleLines
        for minute in (16 * 60)..<(16 * 60 + 2) { try await store.record(sample(Double(minute), 59)) }
        let loaded = try await store.samples(from: .distantPast)
        #expect(loaded.count == 5)
        #expect(await store.activity.decodedSampleLines == decoded + 2, "the closed day isn't decoded again")
        // A sample from a clock set back lands in the closed day, which is read on from its end.
        try await store.record(sample(Double(lastMinutes.lowerBound) - 10, 61))
        #expect(try await store.samples(from: .distantPast) == onDisk())
        #expect(await store.activity.decodedSampleLines == decoded + 3)
    }

    @Test func theLegacyMigrationRunsOncePerSession() async throws {
        defer { removeDirectory() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = directory.appendingPathComponent("samples.jsonl")
        func writeLegacy(_ samples: [HistorySample]) throws {
            let encoder = JSONEncoder()
            let lines = try samples.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
            try (lines.joined(separator: "\n") + "\n").write(to: legacy, atomically: true, encoding: .utf8)
        }
        try writeLegacy([sample(0, 90), sample(24 * 60, 80)])
        let store = store()
        #expect(try await store.samples(from: .distantPast).count == 2)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(try await store.samples(from: .distantPast).count == 2)
        #expect(await store.activity.decodedSampleLines == 2, "the split files are decoded once")
        // No version writes the old file any more: this session doesn't look for it again...
        try writeLegacy([sample(2 * 24 * 60, 70)])
        try await store.record(sample(24 * 60 + 1, 79))
        #expect(try await store.samples(from: .distantPast).count == 3)
        #expect(await store.activity.legacyChecks == 1)
        #expect(FileManager.default.fileExists(atPath: legacy.path))
        // ...and the next one splits it.
        #expect(try await onDisk().count == 4)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func theCacheAlwaysMatchesTheFiles() async throws {
        defer { removeDirectory() }
        let store = store()
        var minute = 0.0
        for step in 0..<60 {
            minute += step % 7 == 0 ? 6 * 60 : 1
            try await store.record(sample(minute, Double(90 - step % 50), step % 9 < 3 ? .charging : .discharging))
            if step % 5 == 0 { #expect(try await store.samples(from: .distantPast) == onDisk()) }
        }
        #expect(try await store.samples(from: .distantPast) == onDisk())
        #expect(try await store.latestSampleTime() == onDisk().last?.time)
    }
}

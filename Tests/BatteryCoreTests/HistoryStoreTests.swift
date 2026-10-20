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
}

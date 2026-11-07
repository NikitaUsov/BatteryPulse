import BatteryCore
import Foundation
import Synchronization
import Testing

@testable import BatterySource

/// The Charge Limit's reader: one read of powerd's file per trigger of its policy, the last number
/// kept on the adapter between them, none on battery (BatteryCore's `SystemChargeLimitReadPolicy`
/// decides the triggers).
@Suite struct SystemChargeLimitReaderTests {
    /// A reader whose file reads give `outcome` and are counted.
    final class CountingFile: Sendable {
        private let state: Mutex<(outcome: SystemChargeLimitSource.Outcome, reads: Int)>

        init(_ outcome: SystemChargeLimitSource.Outcome) {
            state = Mutex((outcome, 0))
        }

        var reads: Int { state.withLock { $0.reads } }

        func set(_ outcome: SystemChargeLimitSource.Outcome) {
            state.withLock { $0.outcome = outcome }
        }

        func reader() -> SystemChargeLimitReader {
            SystemChargeLimitReader(logsReads: false) { [self] in
                state.withLock { state in
                    state.reads += 1
                    return state.outcome
                }
            }
        }
    }

    static func reading(adapter: Bool, held: Bool = false) -> BatteryReading {
        BatteryReading(
            snapshot: BatterySnapshot(
                timestamp: Date(timeIntervalSince1970: 1_800_000_000), chargePercent: 80,
                chargeState: adapter ? (held ? .notCharging : .charging) : .discharging,
                isExternalPowerConnected: adapter, notChargingReason: held ? 0x0100_0000 : 0))
    }

    /// The number each reading gets, and the file's reads after it.
    static func numbers(
        _ readings: [(BatteryReading, powerShown: Bool)], file: CountingFile, reader: SystemChargeLimitReader
    ) -> [(Int?, Int)] {
        readings.map { reading, powerShown in
            var reading = reading
            reader.update(&reading, powerShown: powerShown)
            return (reading.snapshot.systemChargeLimitPercent, file.reads)
        }
    }

    @Test func readsOncePerTriggerAndKeepsTheNumberOnTheAdapter() {
        let file = CountingFile(.manualChargeLimit(80))
        let reader = file.reader()
        let numbers = Self.numbers(
            [
                (Self.reading(adapter: false), false), (Self.reading(adapter: true), false),
                (Self.reading(adapter: true), false), (Self.reading(adapter: true, held: true), false),
                (Self.reading(adapter: true, held: true), true), (Self.reading(adapter: true, held: true), false),
                (Self.reading(adapter: false), false), (Self.reading(adapter: false), true),
            ], file: file, reader: reader)
        #expect(numbers.map(\.0) == [nil, 80, 80, 80, 80, 80, nil, nil])
        #expect(numbers.map(\.1) == [0, 1, 1, 2, 3, 3, 3, 3])
    }

    /// A read that finds no number takes the last one away, and the next trigger brings a new one.
    @Test func eachReadReplacesTheNumber() {
        let file = CountingFile(.manualChargeLimit(80))
        let reader = file.reader()
        var reading = Self.reading(adapter: true, held: true)
        reader.update(&reading)
        #expect(reading.snapshot.systemChargeLimitPercent == 80)
        // The limit raised to 100 % at the hold: the hold ends, and no policy is left.
        file.set(.noPolicy)
        reading = Self.reading(adapter: true)
        reader.update(&reading)
        #expect(reading.snapshot.systemChargeLimitPercent == nil)
        reader.update(&reading)
        #expect(reading.snapshot.systemChargeLimitPercent == nil)
        // Set to 90 % while charging, seen when Power appears.
        file.set(.manualChargeLimit(90))
        reader.update(&reading, powerShown: true)
        #expect(reading.snapshot.systemChargeLimitPercent == 90)
        #expect(file.reads == 3)
        // A reading that comes with its own number gets the reader's.
        var demo = Self.reading(adapter: false)
        demo.snapshot.systemChargeLimitPercent = 85
        reader.update(&demo)
        #expect(demo.snapshot.systemChargeLimitPercent == nil)
    }

    /// The monitor's restart and Demo Mode start the reads over.
    @Test func resetReadsAgainOnTheAdapter() {
        let file = CountingFile(.manualChargeLimit(80))
        let reader = file.reader()
        var reading = Self.reading(adapter: true)
        reader.update(&reading)
        reader.update(&reading)
        #expect(file.reads == 1)
        reader.reset()
        file.set(.manualChargeLimit(85))
        reading = Self.reading(adapter: true)
        reader.update(&reading)
        #expect(file.reads == 2)
        #expect(reading.snapshot.systemChargeLimitPercent == 85)
    }

    /// The file itself: what a read finds where powerd keeps it, or in a file of the test's.
    @Test func aReadOfTheFileSaysWhatItFound() throws {
        #expect(SystemChargeLimitReader.path == "/Library/Preferences/com.apple.powerd.charging.plist")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(SystemChargeLimitReader.read(folder.appendingPathComponent("none.plist")) == .noFile)
        #expect(SystemChargeLimitReader.read(folder) == .notReadable)
        let garbage = folder.appendingPathComponent("garbage.plist")
        try Data("not a property list".utf8).write(to: garbage)
        #expect(SystemChargeLimitReader.read(garbage) == .unknownFormat)
        let empty = folder.appendingPathComponent("empty.plist")
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["bootSessionUUID": "00000000-0000-4000-8000-000000000000"], format: .binary, options: 0)
        try plist.write(to: empty)
        #expect(SystemChargeLimitReader.read(empty) == .noPolicy)

        // The reader at a path reads that file.
        let reader = SystemChargeLimitReader(url: empty, logsReads: false)
        var reading = Self.reading(adapter: true)
        reader.update(&reading)
        #expect(reading.snapshot.systemChargeLimitPercent == nil)
    }
}

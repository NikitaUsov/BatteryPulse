import Foundation
import Testing

@testable import BatteryCore

@Suite struct CaptureRecorderTests {
    private let t0 = Fixture.timestamp
    private let utc = TimeZone(secondsFromGMT: 0) ?? .current

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func makeRecorder(
        maxCaptures: Int = CaptureRecorder.defaultMaxCaptures, maxTimelineRows: Int = 100,
        flapLimit: Int = CaptureRecorder.defaultFlapLimit
    ) -> CaptureRecorder {
        CaptureRecorder(
            maxCaptures: maxCaptures, maxTimelineRows: maxTimelineRows, flapLimit: flapLimit, timeZone: utc)
    }

    /// The charging capture, and the same moment with charging stopped as Charge Limit might stop it.
    private func chargingAndHeld() throws -> (charging: BatteryReading, held: BatteryReading) {
        let charging = try Fixture.m5Charging.reading()
        let held = charging.editing(["AppleSmartBattery", "IsCharging"], to: .bool(false))
            .editing(["AppleSmartBattery", "ChargerData", "NotChargingReason"], to: .int(4))
        return (charging, held)
    }

    // MARK: - Fingerprint

    @Test func fingerprintIgnoresLiveValues() throws {
        let reading = try Fixture.m5OnBatterySMC.reading()
        var live =
            reading
            .editing(["AppleSmartBattery", "Voltage"], to: .int(12_000))
            .editing(["AppleSmartBattery", "Amperage"], to: .int(-1_500))
            .editing(["AppleSmartBattery", "BatteryData", "RemainingCapacity"], to: .int(2_000))
            .editing(["AppleSmartBattery", "UpdateTime"], to: .int(1_792_045_999))
            .editing(
                ["AppleSmartBattery", "IORegistryEntryChildren", 0, "BatteryData", "Temperature"], to: .int(3_500))
        #expect(!reading.smc.isEmpty)
        for key in reading.smc.keys {
            live = live.editing(["AppleSMC", .key(key), "Bytes"], to: .data(Data([0x12, 0x34])))
        }
        #expect(live.smc != reading.smc)
        #expect(ChargeStateFingerprint(live) == ChargeStateFingerprint(reading))
    }

    @Test func fingerprintSeesPlugIn() throws {
        let changes = ChargeStateFingerprint(try Fixture.m5PluggedIn10s.reading())
            .changes(from: ChargeStateFingerprint(try Fixture.m5OnBatterySMC.reading()))
        #expect(changes.contains(change("AppleSmartBattery.ExternalConnected", "false", "true")))
        #expect(changes.contains(change("PowerSource.Power Source State", "Battery Power", "AC Power")))
        #expect(changes.map(\.path) == changes.map(\.path).sorted())
    }

    @Test func nameRuleCatchesChildKeys() throws {
        let path = "AppleSmartBattery.IORegistryEntryChildren[1].ChargerData.ChargerHwIlimBackoffReason"
        #expect(!ChargeStateFingerprint.watchedPaths.contains(path))
        let changes = ChargeStateFingerprint(try Fixture.m5PluggedIn10s.reading())
            .changes(from: ChargeStateFingerprint(try Fixture.m5OnBatterySMC.reading()))
        #expect(changes.contains(change(path, "0", "16")))
    }

    @Test func fingerprintSeesChargingStart() throws {
        let changes = ChargeStateFingerprint(try Fixture.m5Charging.reading())
            .changes(from: ChargeStateFingerprint(try Fixture.m5PluggedIn10s.reading()))
        #expect(changes.contains(change("AppleSmartBattery.IsCharging", "false", "true")))
        #expect(changes.contains(change("AppleSmartBattery.ChargerData.NotChargingReason", "128", "0")))
        #expect(changes.contains(change("AppleSmartBattery.PowerDistribution.IPDChargingAllowed", "0", "1")))
        #expect(changes.contains(change("PowerSource.Is Charging", "false", "true")))
        #expect(
            changes.first { $0.path == "AppleSmartBattery.IsCharging" }?.description
                == "AppleSmartBattery.IsCharging: false → true")
    }

    @Test func newPowerSourceKeyIsAChange() throws {
        let reading = try Fixture.m5OnBattery.reading()
        let changed =
            reading
            .editing(["PowerSource", "Test Hold Engaged"], to: .bool(true))
            .editing(["PowerSource", "Test Key"], to: .int(1))
        let changes = ChargeStateFingerprint(changed).changes(from: ChargeStateFingerprint(reading))
        #expect(
            changes == [
                change("PowerSource.Test Hold Engaged", "absent", "true"),
                change("PowerSource.Test Key", "absent", "present"),
            ])
    }

    @Test func ignoredCounterDoesNotTrigger() throws {
        let reading = try Fixture.m5OnBatterySMC.reading()
        let raised =
            reading
            .editing(["AppleSmartBattery", "ChargerData", "TimeChargingThermallyLimited"], to: .int(120))
            .editing(
                ["AppleSmartBattery", "IORegistryEntryChildren", 1, "ChargerData", "TimeChargingThermallyLimited"],
                to: .int(120))
        #expect(raised != reading)
        #expect(ChargeStateFingerprint(raised) == ChargeStateFingerprint(reading))
    }

    // MARK: - Recorder

    @Test func firstReadingIsStart() throws {
        var recorder = makeRecorder()
        let step = recorder.record(try Fixture.m5OnBattery.reading(), at: t0)
        #expect(step.captures.map(\.reason) == [.start])
        #expect(step.captures.map(\.number) == [1])
        #expect(step.captures.first?.date == t0)
        #expect(step.changes.isEmpty)
        #expect(step.timelineRow.split(separator: "\t", omittingEmptySubsequences: false).count == 15)
        #expect(step.summary?.hasSuffix("start (capture 0001)") == true)
        #expect(recorder.capturesWritten == 1)
        #expect(CaptureRecorder.timelineHeader.split(separator: "\t").count == 15)
    }

    @Test func sameStateWritesNothing() throws {
        var recorder = makeRecorder()
        let reading = try Fixture.m5OnBattery.reading()
        _ = recorder.record(reading, at: t0)
        let step = recorder.record(reading, at: at(5))
        #expect(step.captures.isEmpty)
        #expect(step.timelineRow.hasSuffix("\t-\t-"))
        #expect(step.notices.isEmpty)
        #expect(step.summary == nil)
    }

    @Test func changeWritesBeforeAndAfter() throws {
        let (charging, held) = try chargingAndHeld()
        var recorder = makeRecorder()
        _ = recorder.record(charging, at: t0)
        #expect(recorder.record(charging, at: at(40)).captures.isEmpty)
        let step = recorder.record(held, at: at(45))
        #expect(step.captures.map(\.reason) == [.before, .change])
        #expect(step.captures.map(\.number) == [2, 3])
        #expect(step.captures.map(\.date) == [at(40), at(45)])
        #expect(step.captures.map(\.reading) == [charging, held])
        #expect(
            step.changes == [
                change("AppleSmartBattery.ChargerData.NotChargingReason", "0", "4"),
                change("AppleSmartBattery.IsCharging", "true", "false"),
            ])
        let fields = step.timelineRow.components(separatedBy: "\t")
        #expect(fields[13] == "0002,0003")
        #expect(
            fields[14]
                == "AppleSmartBattery.ChargerData.NotChargingReason: 0 → 4; AppleSmartBattery.IsCharging: true → false")
        #expect(step.summary?.hasSuffix("AppleSmartBattery.IsCharging: true → false (captures 0002, 0003)") == true)
    }

    @Test func noBeforeWhenPreviousWasWritten() throws {
        let (charging, held) = try chargingAndHeld()
        var recorder = makeRecorder()
        _ = recorder.record(charging, at: t0)
        let step = recorder.record(held, at: at(31))
        #expect(step.captures.map(\.reason) == [.change])
        #expect(step.captures.map(\.number) == [2])
    }

    @Test func tooSoonIsDeferredThenWritten() throws {
        let (charging, held) = try chargingAndHeld()
        var recorder = makeRecorder()
        _ = recorder.record(charging, at: t0)
        var settled = recorder
        let deferred = recorder.record(held, at: at(10))
        #expect(deferred.captures.isEmpty)
        #expect(deferred.timelineRow.hasSuffix("(capture deferred)"))
        #expect(deferred.summary?.hasSuffix("(capture deferred)") == true)
        let written = recorder.record(held, at: at(35))
        #expect(written.captures.map(\.reason) == [.change])
        #expect(written.captures.first?.reading == held)
        #expect(written.captures.first?.date == at(35))

        // Back to the written state before the spacing passed: nothing to keep.
        _ = settled.record(held, at: at(10))
        let back = settled.record(charging, at: at(35))
        #expect(back.captures.isEmpty)
        #expect(!back.timelineRow.contains("deferred"))
    }

    @Test func heartbeat() throws {
        var recorder = makeRecorder()
        let reading = try Fixture.m5OnBattery.reading()
        _ = recorder.record(reading, at: t0)
        #expect(recorder.record(reading, at: at(899)).captures.isEmpty)
        let step = recorder.record(reading, at: at(900))
        #expect(step.captures.map(\.reason) == [.heartbeat])
        #expect(step.summary?.hasSuffix("heartbeat (capture 0002)") == true)
        #expect(recorder.record(reading, at: at(905)).captures.isEmpty)
    }

    @Test func captureLimit() throws {
        let (charging, held) = try chargingAndHeld()
        var recorder = makeRecorder(maxCaptures: 3)
        var captures: [CaptureRecorder.Capture] = []
        var notices: [String] = []
        for turn in 0..<8 {
            let step = recorder.record(turn.isMultiple(of: 2) ? charging : held, at: at(Double(turn) * 40))
            captures += step.captures
            notices += step.notices
            #expect(!step.timelineRow.isEmpty)
        }
        #expect(captures.map(\.number) == [1, 2, 3])
        #expect(recorder.capturesWritten == 3)
        #expect(notices == ["Reached 3 captures; only the timeline is written from now on."])

        // One slot left with `before` and `change` due: the change is kept.
        var lastSlot = makeRecorder(maxCaptures: 3)
        _ = lastSlot.record(charging, at: t0)
        _ = lastSlot.record(held, at: at(40))
        #expect(lastSlot.record(held, at: at(80)).captures.isEmpty)
        let step = lastSlot.record(charging, at: at(120))
        #expect(step.captures.map(\.reason) == [.change])
        #expect(step.captures.map(\.number) == [3])
        #expect(step.captures.first?.reading == charging)
        #expect(step.notices == ["Reached 3 captures; only the timeline is written from now on."])
    }

    @Test func flappingKeyIsDemoted() throws {
        let path = "AppleSmartBattery.PortControllerInfo[0].PortControllerLoserReason"
        let reading = try Fixture.m5OnBatterySMC.reading()
        func loser(_ value: Int64) -> BatteryReading {
            reading.editing(
                ["AppleSmartBattery", "PortControllerInfo", 0, "PortControllerLoserReason"], to: .int(value))
        }
        var recorder = makeRecorder(flapLimit: 3)
        _ = recorder.record(loser(1), at: t0)
        var reasons: [CaptureRecorder.Reason] = []
        var notices: [String] = []
        var lastRow = ""
        for turn in 1...8 {
            let step = recorder.record(loser(turn.isMultiple(of: 2) ? 1 : 0), at: at(Double(turn) * 40))
            reasons += step.captures.map(\.reason)
            notices += step.notices
            lastRow = step.timelineRow
        }
        #expect(reasons == [.change, .change, .change])
        #expect(notices == ["\(path) keeps changing; it no longer triggers captures (the timeline still lists it)."])
        #expect(lastRow.hasSuffix("\t\(path): 0 → 1"))

        // The last flip (at 320 s) wasn't written, so it is kept as the moment before.
        let charging = loser(1).editing(["AppleSmartBattery", "IsCharging"], to: .bool(true))
        #expect(recorder.record(charging, at: at(400)).captures.map(\.reason) == [.before, .change])
    }

    @Test func missingReadingWritesARow() throws {
        var recorder = makeRecorder()
        let reading = try Fixture.m5OnBattery.reading()
        _ = recorder.record(reading, at: t0)
        let step = recorder.record(nil, at: at(5))
        #expect(step.captures.isEmpty)
        #expect(step.changes.isEmpty)
        #expect(step.summary == nil)
        let fields = step.timelineRow.components(separatedBy: "\t")
        #expect(fields.count == 15)
        #expect(fields.first?.hasPrefix("2027-") == true)
        #expect(fields.dropFirst().dropLast().allSatisfy { $0 == "-" })
        #expect(fields.last == "no reading")

        let next = recorder.record(reading, at: at(10))
        #expect(next.captures.isEmpty)
        #expect(next.changes.isEmpty)
        #expect(next.summary == nil)
    }

    @Test func timelineLimit() throws {
        var recorder = makeRecorder(maxTimelineRows: 3)
        let reading = try Fixture.m5OnBattery.reading()
        let finished = [
            recorder.record(reading, at: t0).isFinished,
            recorder.record(nil, at: at(5)).isFinished,
            recorder.record(reading, at: at(10)).isFinished,
        ]
        #expect(finished == [false, false, true])
    }

    @Test func fileNames() throws {
        let date = Date(timeIntervalSince1970: 1_792_089_005)  // 2026-10-15T18:30:05Z
        #expect(
            CaptureRecorder.fileName(number: 7, reason: .change, date: date) == "0007-20261015T183005Z-change.plist")
        #expect(CaptureRecorder.fileName(number: 12_345, reason: .before, date: date).hasPrefix("12345-"))
        let reading = try Fixture.m5OnBattery.reading()
        for identifier in ["Europe/Moscow", "America/Los_Angeles", "UTC"] {
            var recorder = CaptureRecorder(timeZone: try #require(TimeZone(identifier: identifier)))
            let step = recorder.record(reading, at: date)
            #expect(step.captures.map(\.fileName) == ["0001-20261015T183005Z-start.plist"], "\(identifier)")
        }
    }

    @Test func timelineRowFormat() throws {
        let reading = try Fixture.m5Charging.reading()
        let snapshot = reading.snapshot
        var recorder = CaptureRecorder(timeZone: try #require(TimeZone(identifier: "Europe/Moscow")))
        let row = recorder.record(reading, at: Date(timeIntervalSince1970: 1_792_089_005)).timelineRow
        let fields = row.components(separatedBy: "\t")
        #expect(fields.count == 15)
        #expect(fields[0] == "2026-10-15T21:30:05+03:00")
        #expect(fields[2] == snapshot.chargeState.rawValue)
        #expect(fields[13] == "0001")
        #expect(fields[14] == "-")

        let optionalColumns: [(Int, Any?)] = [
            (1, snapshot.chargePercent), (3, snapshot.isExternalPowerConnected), (4, snapshot.notChargingReason),
            (5, snapshot.currentCapacityMAh), (6, snapshot.fullChargeCapacityMAh), (7, snapshot.amperageMA),
            (8, snapshot.voltageMV), (9, snapshot.chargingCurrentMA), (10, snapshot.systemPowerInWatts),
            (11, snapshot.temperatureCelsius), (12, snapshot.gaugeUpdatedAt),
        ]
        for (column, value) in optionalColumns {
            #expect((fields[column] == "-") == (value == nil), "column \(column): \(fields[column])")
        }
        #expect(snapshot.systemPowerInWatts != nil)
        for column in [10, 11] where fields[column] != "-" {
            #expect(fields[column].wholeMatch(of: #/-?[0-9]+\.[0-9]/#) != nil, "column \(column): \(fields[column])")
        }
        if let percent = snapshot.chargePercent { #expect(fields[1] == String(Int(percent.rounded()))) }
        if let current = snapshot.amperageMA { #expect(fields[7] == String(current)) }
        if snapshot.gaugeUpdatedAt != nil { #expect(fields[12].hasSuffix("+03:00")) }
    }

    @Test func valuesStayOnOneLine() throws {
        let reading = try Fixture.m5OnBattery.reading()
        let noted = reading.editing(["PowerSource", "Hold Note"], to: .string("a\tb\nc"))
        #expect(ChargeStateFingerprint(noted).values["PowerSource.Hold Note"] == "a b c")
        var recorder = makeRecorder()
        _ = recorder.record(reading, at: t0)
        let step = recorder.record(noted, at: at(40))
        #expect(step.timelineRow.components(separatedBy: "\t").last == "PowerSource.Hold Note: absent → a b c")
        #expect(!step.timelineRow.contains("\n"))
    }

    private func change(_ path: String, _ old: String, _ new: String) -> ChargeStateFingerprint.Change {
        ChargeStateFingerprint.Change(path: path, old: old, new: new)
    }
}

/// One step of a key path into a raw capture: a dictionary key or an array index.
enum CapturePathStep: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case key(String)
    case index(Int)

    init(stringLiteral value: String) { self = .key(value) }
    init(integerLiteral value: Int) { self = .index(value) }
}

extension BatteryReading {
    /// A copy whose raw capture has `value` at `path` (removed when nil), parsed again.
    func editing(_ path: [CapturePathStep], to value: PropertyValue?) -> BatteryReading {
        let capture = Self.replacing(at: path[...], in: .dictionary(rawCapture), with: value)
        return BatteryReading(rawCapture: capture?.dictionaryValue ?? [:], timestamp: snapshot.timestamp)
    }

    private static func replacing(
        at path: ArraySlice<CapturePathStep>, in node: PropertyValue, with value: PropertyValue?
    ) -> PropertyValue? {
        guard let step = path.first else { return value }
        switch (step, node) {
        case (.key(let key), .dictionary(var dictionary)):
            dictionary[key] = replacing(at: path.dropFirst(), in: dictionary[key] ?? .dictionary([:]), with: value)
            return .dictionary(dictionary)
        case (.index(let index), .array(var items)) where items.indices.contains(index):
            if let item = replacing(at: path.dropFirst(), in: items[index], with: value) {
                items[index] = item
            } else {
                items.remove(at: index)
            }
            return .array(items)
        default:
            Issue.record("The capture has no \(step) here.")
            return node
        }
    }
}

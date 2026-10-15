import Foundation
import Testing

@testable import BatteryCore

@Suite struct BatteryPresentationTests {
    @Test(
        arguments: [
            (95.0, ChargeState.discharging, "battery.100percent"),
            (88.0, .discharging, "battery.100percent"),
            (70.0, .discharging, "battery.75percent"),
            (50.0, .notCharging, "battery.50percent"),
            (20.0, .discharging, "battery.25percent"),
            (5.0, .discharging, "battery.0percent"),
            (40.0, .charging, "battery.100percent.bolt"),
        ])
    func symbolName(percent: Double, state: ChargeState, expected: String) {
        let s = BatterySnapshot(timestamp: .now, chargePercent: percent, chargeState: state)
        #expect(BatteryPresentation.symbolName(for: s) == expected)
    }

    @Test func symbolWithoutData() {
        #expect(BatteryPresentation.symbolName(for: nil) == "battery.0percent")
    }

    @Test(
        arguments: [
            (50.0, ChargeState.discharging, BatteryPresentation.LevelTier.normal),
            (20.0, .discharging, .low),
            (10.0, .discharging, .critical),
            (5.0, .charging, .normal),
        ])
    func levelTiers(percent: Double, state: ChargeState, expected: BatteryPresentation.LevelTier) {
        let s = BatterySnapshot(timestamp: .now, chargePercent: percent, chargeState: state)
        #expect(BatteryPresentation.levelTier(for: s) == expected)
    }

    @Test(
        arguments: [
            (nil as String?, 5760, BatteryPresentation.LevelTier.normal),
            ("Normal", 4600, .low),
            ("Fair", 5760, .low),
            ("Service Recommended", 4000, .low),
            ("Check Battery", 5760, .critical),
            ("Poor", 5760, .critical),
        ])
    func healthTiers(condition: String?, nominalMAh: Int, expected: BatteryPresentation.LevelTier) {
        var s = BatterySnapshot(timestamp: .now)
        s.healthCondition = condition
        s.designCapacityMAh = 5760
        s.nominalChargeCapacityMAh = nominalMAh
        #expect(BatteryPresentation.healthTier(for: s) == expected)
    }

    @Test func rawEntriesFlattenNestedValues() {
        let entries = RawEntry.flatten([
            "B": .dictionary(["Design": .int(5760), "Cells": .array([.int(1), .int(2)])]),
            "A": .bool(true),
            "Empty": .dictionary([:]),
        ])
        #expect(
            entries == [
                RawEntry(path: "A", property: .bool(true)),
                RawEntry(path: "B.Cells[0]", property: .int(1)),
                RawEntry(path: "B.Cells[1]", property: .int(2)),
                RawEntry(path: "B.Design", property: .int(5760)),
                RawEntry(path: "Empty", property: .dictionary([:])),
            ])
    }

    @Test func realCaptureFlattensToUniquePaths() throws {
        let entries = RawEntry.flatten(try Fixture.m5Charging.reading().redactedRawCapture)
        #expect(entries.count > 300)
        #expect(Set(entries.map(\.path)).count == entries.count)
        #expect(entries.contains(RawEntry(path: "AppleSmartBattery.BatteryData.DesignCapacity", property: .int(5760))))
        #expect(!entries.contains { $0.path.hasSuffix("SerialString") && $0.value != "REDACTED" })
    }
}

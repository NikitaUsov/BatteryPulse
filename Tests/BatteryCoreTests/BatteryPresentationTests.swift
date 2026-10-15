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

    // MARK: iPhone and iPad

    @Test(
        arguments: [
            (50.0 as Double?, ChargeState.discharging, BatteryPresentation.LevelTier.normal),
            (20, .discharging, .low),
            (10, .notCharging, .critical),
            (5, .charging, .normal),
            (nil, .discharging, .normal),
        ])
    func deviceLevelTier(percent: Double?, state: ChargeState, expected: BatteryPresentation.LevelTier) {
        #expect(BatteryPresentation.levelTier(percent: percent, state: state) == expected)
    }

    @Test func deviceHealthTier() {
        func tier(_ percent: Double?, error: String? = nil, failure: Int? = nil) -> BatteryPresentation.LevelTier {
            BatteryPresentation.healthTier(
                device: IDeviceBattery(
                    maximumCapacityPercent: percent, errorCondition: error, permanentFailureStatus: failure))
        }
        #expect(tier(95, error: "Cell Check Fault") == .critical)
        #expect(tier(95, failure: 0x10) == .critical)
        #expect(tier(95, failure: 0) == .normal)
        #expect(tier(79) == .low)
        #expect(tier(80) == .normal)
        #expect(tier(95) == .normal)
        #expect(tier(nil) == .normal)
    }

    @Test func snapshotTiersAndSymbolsUnchanged() {
        for percent in stride(from: 0.0, through: 100, by: 1) {
            for state in ChargeState.allCases {
                let s = BatterySnapshot(timestamp: .now, chargePercent: percent, chargeState: state)
                #expect(
                    BatteryPresentation.symbolName(for: s)
                        == BatteryPresentation.symbolName(percent: percent, state: state))
                #expect(
                    BatteryPresentation.levelTier(for: s)
                        == BatteryPresentation.levelTier(percent: percent, state: state))
            }
        }
        #expect(BatteryPresentation.symbolName(for: BatterySnapshot(timestamp: .now)) == "battery.0percent")
        #expect(BatteryPresentation.symbolName(percent: nil, state: .charging) == "battery.0percent")
        #expect(BatteryPresentation.symbolName(percent: 50, state: nil) == "battery.50percent")
    }
}

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

    @Test func menuBarTitles() throws {
        let s = try Fixture.m5OnBattery.snapshot()
        #expect(BatteryPresentation.menuBarTitle(for: s, style: .percent) == "70%")
        #expect(BatteryPresentation.menuBarTitle(for: s, style: .power) == "−7.5 W")
        #expect(BatteryPresentation.menuBarTitle(for: s, style: .percentAndPower) == "70% · −7.5 W")
        #expect(BatteryPresentation.menuBarTitle(for: s, style: .iconOnly) == "")
        #expect(BatteryPresentation.menuBarTitle(for: nil, style: .percent) == "")
    }

    @Test func iconHidesOnlyWhenTextRemains() {
        #expect(BatteryPresentation.showsIcon(.standard, title: "70%"))
        #expect(BatteryPresentation.showsIcon(.large, title: "70%"))
        #expect(!BatteryPresentation.showsIcon(.hidden, title: "70%"))
        // Icon-only style (or no data yet): hiding would leave an empty, unclickable item.
        #expect(BatteryPresentation.showsIcon(.hidden, title: ""))
    }

    @Test func onlyPowerStylesNeedPolling() {
        #expect(MenuBarStyle.allCases.filter(\.showsPower) == [.power, .percentAndPower])
    }

    @Test func powerText() {
        #expect(BatteryPresentation.powerText(31.25) == "+31.2 W")
        #expect(BatteryPresentation.powerText(-7.45) == "−7.5 W")
        #expect(BatteryPresentation.powerText(0.01) == "0.0 W")
    }

    @Test func stateTitles() {
        func title(_ state: ChargeState, optimized: Bool? = nil) -> String {
            BatteryPresentation.stateTitle(
                for: BatterySnapshot(timestamp: .now, chargeState: state, isOptimizedChargingEngaged: optimized))
        }
        #expect(title(.charging) == "Charging")
        #expect(title(.discharging) == "On battery")
        #expect(title(.charged) == "Fully charged")
        #expect(title(.notCharging) == "Not charging")
        #expect(title(.notCharging, optimized: true) == "Charging on hold")
    }

    @Test func timeTexts() throws {
        #expect(try BatteryPresentation.timeText(for: Fixture.m5OnBattery.snapshot()) == "5 h 42 min left")
        #expect(try BatteryPresentation.timeText(for: Fixture.m5Charging.snapshot()) == "Calculating time…")
        #expect(try BatteryPresentation.timeText(for: Fixture.legacyCharging.snapshot()) == "Full in 52 min")
        let derived = BatterySnapshot(
            timestamp: .now, chargeState: .discharging, currentCapacityMAh: 3000, amperageMA: -1500
        )
        #expect(BatteryPresentation.timeText(for: derived) == "≈ 2 h 0 min left")
        #expect(BatteryPresentation.timeText(for: BatterySnapshot(timestamp: .now, chargeState: .charged)) == nil)
    }

    @Test func popoverSummary() throws {
        let lines = BatteryPresentation.summaryLines(for: try Fixture.m5Charging.snapshot())
        #expect(
            lines == [
                .init(label: "Battery power", value: "+4.7 W"),
                .init(label: "Health", value: "100% · Normal"),
                .init(label: "Cycles", value: "48 of 1000"),
                .init(label: "Adapter", value: "60 W"),
                .init(label: "System input", value: "18.5 W"),
                .init(label: "System load", value: "14.0 W"),
            ])
        let onBattery = BatteryPresentation.summaryLines(for: try Fixture.m5OnBattery.snapshot())
        #expect(!onBattery.contains { $0.label == "System input" || $0.label == "Adapter" })
    }

    @Test func rawEntriesFlattenNestedValues() {
        let entries = RawEntry.flatten([
            "B": .dictionary(["Design": .int(5760), "Cells": .array([.int(1), .int(2)])]),
            "A": .bool(true),
            "Empty": .dictionary([:]),
        ])
        #expect(
            entries == [
                RawEntry(path: "A", value: "true"),
                RawEntry(path: "B.Cells[0]", value: "1"),
                RawEntry(path: "B.Cells[1]", value: "2"),
                RawEntry(path: "B.Design", value: "5760"),
                RawEntry(path: "Empty", value: "{}"),
            ])
    }

    @Test func realCaptureFlattensToUniquePaths() throws {
        let entries = RawEntry.flatten(try Fixture.m5Charging.reading().redactedRawCapture)
        #expect(entries.count > 300)
        #expect(Set(entries.map(\.path)).count == entries.count)
        #expect(entries.contains(RawEntry(path: "AppleSmartBattery.BatteryData.DesignCapacity", value: "5760")))
        #expect(!entries.contains { $0.path.hasSuffix("SerialString") && $0.value != "REDACTED" })
    }
}

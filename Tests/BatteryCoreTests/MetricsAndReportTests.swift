import Foundation
import Testing

@testable import BatteryCore

@Suite struct MetricsTests {
    @Test func healthIsCappedLikeMacOS() throws {
        // A new M5 battery holds more than its design capacity; macOS still shows 100 %.
        let s = try Fixture.m5OnBattery.snapshot()
        let ratio = try #require(s.capacityToDesignPercent)
        #expect(abs(ratio - 6006.0 / 5760.0 * 100) < 0.0001)
        #expect(s.healthPercent == 100)
        #expect(s.cycleLifeUsed == 0.048)
    }

    @Test func hardwareChargeFromCapacity() throws {
        // macOS shows 70 %; the gauge holds 3901 of 5862 mAh (66.5 %).
        let s = try Fixture.m5OnBattery.snapshot()
        #expect(abs(try #require(s.hardwareChargePercent) - 3901.0 / 5862.0 * 100) < 0.0001)
        #expect(BatterySnapshot(timestamp: .now).hardwareChargePercent == nil)
    }

    @Test func healthBelowDesign() throws {
        let s = try Fixture.legacyDischarging.snapshot()
        let health = try #require(s.healthPercent)
        #expect(abs(health - 6024.0 / 6249.0 * 100) < 0.0001)
    }

    @Test func healthFallsBackToFullChargeCapacity() throws {
        let s = BatterySnapshot(timestamp: .now, fullChargeCapacityMAh: 4500, designCapacityMAh: 5000)
        #expect(s.healthPercent == 90)
    }

    @Test func batteryPowerIsSigned() throws {
        let discharging = try Fixture.m5OnBattery.snapshot()
        #expect(abs(try #require(discharging.batteryPowerWatts) - (-7.451712)) < 0.000001)
        let charging = try Fixture.m5Charging.snapshot()
        #expect(abs(try #require(charging.batteryPowerWatts) - 4.708608) < 0.000001)
        #expect(charging.systemPowerInWatts == 18.545)
        // 453 µWh per one-second sample = 1.631 W.
        #expect(charging.adapterEfficiencyLossWatts == 1.631)
    }

    @Test func cellSpread() throws {
        #expect(try Fixture.legacyDischarging.snapshot().cellVoltageSpreadMV == 3)
        #expect(try Fixture.m5OnBattery.snapshot().cellVoltageSpreadMV == nil)
        #expect(BatterySnapshot(timestamp: .now, cellVoltagesMV: [4100]).cellVoltageSpreadMV == nil)
    }

    @Test func timeEstimatesFallBackToCurrent() throws {
        let discharging = BatterySnapshot(
            timestamp: .now, chargeState: .discharging, currentCapacityMAh: 3000, amperageMA: -1500
        )
        #expect(discharging.estimatedTimeToEmptyMinutes == 120)

        let charging = BatterySnapshot(
            timestamp: .now, chargeState: .charging,
            currentCapacityMAh: 3000, fullChargeCapacityMAh: 5000, amperageMA: 4000
        )
        #expect(charging.estimatedTimeToFullMinutes == 30)

        let idle = BatterySnapshot(
            timestamp: .now, chargeState: .discharging, currentCapacityMAh: 3000, amperageMA: -5
        )
        #expect(idle.estimatedTimeToEmptyMinutes == nil, "near-zero current would explode the estimate")
    }

    @Test func noDerivedEstimateWhileMacOSIsCalculating() throws {
        // Real M5 a minute after plugging in: IOPS says -1 and the current (384 mA) is still
        // ramping, so (5866 - 3896) mAh / 384 mA ≈ 5 h would be badly wrong.
        let s = try Fixture.m5Charging.snapshot()
        #expect(s.isTimeRemainingCalculating)
        #expect(s.estimatedTimeToFullMinutes == nil)
    }

    @Test func osEstimateWins() throws {
        let s = try Fixture.m5OnBattery.snapshot()
        #expect(s.estimatedTimeToEmptyMinutes == 342)
    }
}

@Suite struct BatteryReportTests {
    private func value(_ label: String, in s: BatterySnapshot) -> String? {
        BatteryReport.lines(for: s).first { $0.label == label }?.value
    }

    @Test func m5OnBatteryReport() throws {
        let s = try Fixture.m5OnBattery.snapshot()
        #expect(value("Battery", in: s) == "bq40z651")
        #expect(value("Charge", in: s) == "70 %  (3901 of 5862 mAh)")
        #expect(value("State", in: s) == "Discharging")
        #expect(value("Time to empty", in: s) == "5 h 42 min")
        #expect(value("Battery power", in: s) == "-7.5 W  (12.18 V × -612 mA)")
        #expect(value("Health", in: s) == "100.0 %  (6006 of 5760 mAh design = 104.3 %)")
        #expect(value("Condition", in: s) == "Normal")
        #expect(value("Cycles", in: s) == "48 of 1000  (5 % of rated life)")
        // Noise seen on real hardware that must stay hidden on battery.
        #expect(value("Not charging reason", in: s) == nil)
        #expect(value("System input", in: s) == nil)
        #expect(value("Adapter loss", in: s) == nil)
        #expect(value("Temperature", in: s) == nil)
        #expect(value("Cells", in: s) == nil)
    }

    @Test func m5ChargingReport() throws {
        let s = try Fixture.m5Charging.snapshot()
        #expect(value("Time to full", in: s) == "calculating…")
        #expect(value("Battery power", in: s) == "+4.7 W  (12.26 V × 384 mA)")
        #expect(value("Adapter", in: s) == "60 W · 40W Pwr Adapter 60W Max · 20.0 V × 2.99 A")
        #expect(value("System input", in: s) == "18.5 W")
        #expect(value("Adapter loss", in: s) == "1.6 W")
    }

    @Test func legacyReport() throws {
        let s = try Fixture.legacyDischarging.snapshot()
        #expect(value("Battery", in: s) == "bq40z651 · SMP")
        #expect(!BatteryReport.text(for: s).contains("F8Y0000SYNTHETIC"), "serials must not leak into reports")
        #expect(value("Health", in: s) == "96.4 %  (6024 of 6249 mAh design)")
        #expect(value("Temperature", in: s) == "31.1 °C")
        #expect(value("Cells", in: s) == "4144 / 4143 / 4146 mV  (spread 3 mV)")
        #expect(try value("Charger request", in: Fixture.legacyCharging.snapshot()) == "4000 mA at 13.05 V")
        // macOS 27 on Apple silicon asks for a per-cell voltage.
        var m5 = try Fixture.m5OnBatterySMC.snapshot()
        #expect(m5.isChargingVoltagePerCell)
        #expect(try !Fixture.legacyCharging.snapshot().isChargingVoltagePerCell)
        #expect(value("Charger request", in: m5) == nil, "not charging")
        m5.chargingCurrentMA = 2990
        #expect(value("Charger request", in: m5) == "2990 mA at 4.47 V per cell")
        // No voltage yet: neither "per cell" nor a request line.
        m5.chargingVoltageMV = 0
        #expect(!m5.isChargingVoltagePerCell)
        #expect(value("Charger request", in: m5) == nil)
    }

    @Test func derivedTimeIsMarked() {
        let s = BatterySnapshot(
            timestamp: .now, chargeState: .discharging, currentCapacityMAh: 3000, amperageMA: -1500
        )
        #expect(value("Time to empty", in: s) == "≈ 2 h 0 min")
    }

    @Test func slowChargingReasonOnlyWhileCharging() {
        let charging = BatterySnapshot(timestamp: .now, chargeState: .charging, slowChargingReason: 0x4)
        #expect(value("Slow charging reason", in: charging) == "0x4")
        let holding = BatterySnapshot(timestamp: .now, chargeState: .notCharging, slowChargingReason: 0x4)
        #expect(value("Slow charging reason", in: holding) == nil)
    }

    @Test func adapterLossOnlyWithAdapterAndLoss() {
        let onBattery = BatterySnapshot(
            timestamp: .now, chargeState: .discharging, isExternalPowerConnected: false,
            adapterEfficiencyLossMW: 500
        )
        #expect(value("Adapter loss", in: onBattery) == nil)
        let lossless = BatterySnapshot(
            timestamp: .now, chargeState: .notCharging, isExternalPowerConnected: true,
            adapterEfficiencyLossMW: 0
        )
        #expect(value("Adapter loss", in: lossless) == nil)
    }

    @Test func reportKeepsItsGroupOrder() throws {
        let labels = BatteryReport.lines(for: try Fixture.m5Charging.snapshot()).map(\.label)
        // The first line of the charge, health and power groups.
        let starts = ["Charge", "Health", "Adapter"].compactMap { labels.firstIndex(of: $0) }
        #expect(starts.count == 3)
        #expect(starts == starts.sorted())
    }

    @Test func notChargingOnAdapter() {
        let s = BatterySnapshot(
            timestamp: .now, chargeState: .notCharging, isExternalPowerConnected: true,
            isOptimizedChargingEngaged: true, voltageMV: 12100, amperageMA: 0, notChargingReason: 0x80
        )
        #expect(value("State", in: s) == "On power adapter, not charging")
        #expect(value("Optimized charging", in: s) == "holding charge")
        #expect(value("Not charging reason", in: s) == "0x80")
        #expect(value("Battery power", in: s) == "0.0 W  (12.10 V × 0 mA)")
    }

    @Test func textAlignsValuesInOneColumn() throws {
        let s = try Fixture.m5Charging.snapshot()
        let lines = BatteryReport.lines(for: s)
        let column = (lines.map(\.label.count).max() ?? 0) + 2
        let rows = BatteryReport.text(for: s).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(rows.count == lines.count)
        for (row, line) in zip(rows, lines) {
            #expect(row.hasPrefix(line.label))
            #expect(String(row.dropFirst(column)) == line.value)
        }
    }

    @Test func signedValues() {
        #expect(BatteryReport.signed(12.34, 1) == "+12.3")
        #expect(BatteryReport.signed(-0.04, 1) == "0.0")
        #expect(BatteryReport.signed(-3.25, 1) == "-3.2")
    }

    @Test func durations() {
        #expect(BatteryReport.duration(40) == "40 min")
        #expect(BatteryReport.duration(75) == "1 h 15 min")
        #expect(BatteryReport.duration(120) == "2 h 0 min")
    }
}

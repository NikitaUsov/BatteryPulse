import Foundation
import Testing

@testable import BatteryCore

@Suite struct MetricsTests {
    @Test func healthPrefersNominalCapacity() throws {
        let s = try Fixture.appleSiliconDischarging.snapshot()
        let health = try #require(s.healthPercent)
        #expect(abs(health - 6024.0 / 6249.0 * 100) < 0.0001)
        #expect(abs(try #require(s.wearPercent) - (100 - health)) < 0.0001)
        #expect(s.cycleLifeUsed == 0.214)
    }

    @Test func healthFallsBackToFullChargeCapacity() throws {
        let s = try Fixture.intelNotCharging.snapshot()
        #expect(abs(try #require(s.healthPercent) - 5190.0 / 6669.0 * 100) < 0.0001)
    }

    @Test func batteryPowerIsSigned() throws {
        let discharging = try Fixture.appleSiliconDischarging.snapshot()
        #expect(abs(try #require(discharging.batteryPowerWatts) - (-12.731392)) < 0.000001)
        let charging = try Fixture.appleSiliconCharging.snapshot()
        #expect(abs(try #require(charging.batteryPowerWatts) - 49.588) < 0.000001)
        #expect(charging.systemPowerInWatts == 73.21)
    }

    @Test func cellSpread() throws {
        #expect(try Fixture.appleSiliconDischarging.snapshot().cellVoltageSpreadMV == 3)
        #expect(try Fixture.intelNotCharging.snapshot().cellVoltageSpreadMV == 16)
        #expect(BatterySnapshot(timestamp: .now, cellVoltagesMV: [4100]).cellVoltageSpreadMV == nil)
    }

    @Test func timeEstimatesFallBackToCurrent() {
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

    @Test func osEstimateWins() throws {
        let s = try Fixture.appleSiliconDischarging.snapshot()
        #expect(s.estimatedTimeToEmptyMinutes == 291)
    }
}

@Suite struct BatteryReportTests {
    private func value(_ label: String, in s: BatterySnapshot) -> String? {
        BatteryReport.lines(for: s).first { $0.label == label }?.value
    }

    @Test func dischargingReport() throws {
        let s = try Fixture.appleSiliconDischarging.snapshot()
        #expect(value("Battery", in: s) == "bq40z651 · SMP · F8Y0000SYNTHETIC")
        #expect(value("Charge", in: s) == "87 %  (5051 of 5807 mAh)")
        #expect(value("State", in: s) == "Discharging")
        #expect(value("Time to empty", in: s) == "4 h 51 min")
        #expect(value("Battery power", in: s) == "-12.7 W  (12.43 V × -1024 mA)")
        #expect(value("Health", in: s) == "96.4 %  (6024 of 6249 mAh design)")
        #expect(value("Cycles", in: s) == "214 of 1000  (21 % of rated life)")
        #expect(value("Temperature", in: s) == "31.1 °C")
        #expect(value("Cells", in: s) == "4144 / 4143 / 4146 mV  (spread 3 mV)")
        #expect(value("Adapter", in: s) == nil)
        #expect(value("Permanent failure", in: s) == nil)
    }

    @Test func chargingReport() throws {
        let s = try Fixture.appleSiliconCharging.snapshot()
        #expect(value("Time to full", in: s) == "52 min")
        #expect(value("Battery power", in: s) == "+49.6 W  (12.65 V × 3920 mA)")
        #expect(value("Adapter", in: s) == "96 W · 96W USB-C Power Adapter · 20.0 V × 4.70 A")
        #expect(value("Charger request", in: s) == "4000 mA at 13.05 V")
        #expect(value("System input", in: s) == "73.2 W")
    }

    @Test func intelReport() throws {
        let s = try Fixture.intelNotCharging.snapshot()
        #expect(value("State", in: s) == "On power adapter, not charging")
        #expect(value("Optimized charging", in: s) == "holding charge")
        #expect(value("Battery power", in: s) == "0.0 W  (12.10 V × 0 mA)")
        #expect(value("Manufactured", in: s) == "2019-07-15")
        #expect(value("Adapter", in: s) == "87 W · pd charger · 20.0 V × 4.30 A")
    }

    @Test func textAlignsValuesInOneColumn() throws {
        let s = try Fixture.appleSiliconDischarging.snapshot()
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

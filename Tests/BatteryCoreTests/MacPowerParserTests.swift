import Foundation
import Testing

@testable import BatteryCore

@Suite struct MacPowerParserTests {
    @Test func appleSiliconOnBattery() throws {
        let s = try Fixture.appleSiliconDischarging.snapshot()

        #expect(s.timestamp == Fixture.timestamp)
        #expect(s.chargePercent == 87)
        #expect(s.chargeState == .discharging)
        #expect(s.isExternalPowerConnected == false)
        // The power-source estimate wins over the registry's AvgTimeToEmpty (296).
        #expect(s.timeToEmptyMinutes == 291)
        #expect(s.timeToFullMinutes == nil)

        #expect(s.currentCapacityMAh == 5051)
        #expect(s.fullChargeCapacityMAh == 5807)
        #expect(s.nominalChargeCapacityMAh == 6024)
        #expect(s.designCapacityMAh == 6249)
        #expect(s.cycleCount == 214)
        #expect(s.designCycleCount == 1000)
        #expect(s.healthCondition == "Good")
        #expect(s.permanentFailureStatus == 0)

        #expect(s.voltageMV == 12433)
        #expect(s.amperageMA == -1024)
        #expect(s.instantAmperageMA == -1061)
        #expect(s.cellVoltagesMV == [4144, 4143, 4146])
        #expect(s.temperatureCelsius == 31.12)

        #expect(s.adapter == nil, "stale AdapterDetails must be ignored on battery")
        #expect(s.chargingCurrentMA == 0)
        #expect(s.systemLoadMW == 12843)

        #expect(s.deviceName == "bq40z651")
        #expect(s.manufacturer == "SMP")
        #expect(s.serialNumber == "F8Y0000SYNTHETIC")
        #expect(s.manufactureDate == nil)
    }

    @Test func appleSiliconCharging() throws {
        let s = try Fixture.appleSiliconCharging.snapshot()

        #expect(s.chargePercent == 54)
        #expect(s.chargeState == .charging)
        #expect(s.isExternalPowerConnected == true)
        #expect(s.timeToFullMinutes == 52)
        #expect(s.timeToEmptyMinutes == nil)
        #expect(s.amperageMA == 3920)

        // IOPSCopyExternalPowerAdapterDetails is preferred over the registry copy.
        let adapter = try #require(s.adapter)
        #expect(adapter.watts == 96)
        #expect(adapter.voltageMV == 20000)
        #expect(adapter.currentMA == 4700)
        #expect(adapter.name == "96W USB-C Power Adapter")
        #expect(adapter.manufacturer == "Apple Inc.")
        #expect(adapter.serialNumber == "C4H0000SYNTHETIC")
        #expect(adapter.isWireless == false)

        #expect(s.chargingCurrentMA == 4000)
        #expect(s.chargingVoltageMV == 13050)
        #expect(s.systemPowerInMW == 73210)
        #expect(s.systemLoadMW == 22480)
    }

    @Test func intelHoldingChargeOnAdapter() throws {
        let s = try Fixture.intelNotCharging.snapshot()

        #expect(s.chargePercent == 80)
        #expect(s.chargeState == .notCharging)
        #expect(s.isOptimizedChargingEngaged == true)
        #expect(s.timeToEmptyMinutes == nil)
        #expect(s.timeToFullMinutes == nil)

        // Intel reports capacities in mAh directly in CurrentCapacity/MaxCapacity.
        #expect(s.currentCapacityMAh == 4152)
        #expect(s.fullChargeCapacityMAh == 5190)
        #expect(s.nominalChargeCapacityMAh == nil)
        #expect(s.designCapacityMAh == 6669)
        #expect(s.healthCondition == "Service Recommended")

        #expect(s.cellVoltagesMV == [4034, 4035, 4019])
        #expect(s.temperatureCelsius == 30.45)
        #expect(s.serialNumber == "D86000SYNTHETIC")
        #expect(s.manufactureDate == DateComponents(year: 2019, month: 7, day: 15))
        #expect(s.adapter?.watts == 87)
        #expect(s.adapter?.voltageMV == 20000)
    }

    @Test func rawCaptureRoundTrips() throws {
        let reading = try Fixture.appleSiliconCharging.reading()
        let reparsed = BatteryReading(rawCapture: reading.rawCapture, timestamp: Fixture.timestamp)
        #expect(reparsed == reading)
    }

    @Test func redactedCaptureHidesSerialNumbers() throws {
        let reading = try Fixture.appleSiliconCharging.reading()
        let redacted = BatteryReading(rawCapture: reading.redactedRawCapture, timestamp: Fixture.timestamp)
        #expect(redacted.adapterDetails["SerialString"] == .string("REDACTED"))
        #expect(redacted.snapshot.adapter?.serialNumber == "REDACTED")
        // Everything else survives.
        #expect(redacted.snapshot.adapter?.watts == 96)
        #expect(redacted.snapshot.cycleCount == reading.snapshot.cycleCount)

        let discharging = try Fixture.appleSiliconDischarging.reading()
        let text = PropertyValue.dictionary(discharging.redactedRawCapture).description
        #expect(!text.contains("F8Y0000SYNTHETIC"))
        #expect(text.contains("Hardware Serial Number = REDACTED"))
    }

    @Test(
        arguments: [
            (true, true, false, ChargeState.charging),
            (false, true, true, .charged),
            (false, true, false, .notCharging),
            (false, false, false, .discharging),
            (false, nil, nil, .discharging),
        ] as [(Bool?, Bool?, Bool?, ChargeState)])
    func chargeState(isCharging: Bool?, external: Bool?, full: Bool?, expected: ChargeState) {
        #expect(
            MacPowerParser.chargeState(
                isCharging: isCharging, isExternalPowerConnected: external, isFullyCharged: full
            ) == expected)
    }

    @Test func unknownChargeStateWithoutSignals() {
        #expect(
            MacPowerParser.chargeState(
                isCharging: nil, isExternalPowerConnected: nil, isFullyCharged: nil
            ) == .unknown)
    }

    @Test func minuteSentinelsAreDropped() {
        #expect(MacPowerParser.validMinutes(65535) == nil)
        #expect(MacPowerParser.validMinutes(-1) == nil)
        #expect(MacPowerParser.validMinutes(0) == nil)
        #expect(MacPowerParser.validMinutes(42) == 42)
    }

    @Test func implausibleTemperatureIsDropped() {
        #expect(MacPowerParser.celsius(fromCentidegrees: 3112) == 31.12)
        #expect(MacPowerParser.celsius(fromCentidegrees: 29_815) == nil)
    }

    @Test func smartBatteryDateRejectsGarbage() {
        #expect(MacPowerParser.smartBatteryDate(20207) == DateComponents(year: 2019, month: 7, day: 15))
        #expect(MacPowerParser.smartBatteryDate(0) == nil)
        #expect(MacPowerParser.smartBatteryDate(31) == nil)  // month 0
    }

    @Test func emptyInputsProduceEmptySnapshot() {
        let s = BatteryReading(smartBattery: [:], timestamp: Fixture.timestamp).snapshot
        #expect(s == BatterySnapshot(timestamp: Fixture.timestamp))
    }
}

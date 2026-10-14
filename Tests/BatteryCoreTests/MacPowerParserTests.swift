import Foundation
import Testing

@testable import BatteryCore

@Suite struct MacPowerParserTests {
    @Test func m5OnBattery() throws {
        let s = try Fixture.m5OnBattery.snapshot()

        #expect(s.timestamp == Fixture.timestamp)
        #expect(s.chargePercent == 70)
        #expect(s.chargeState == .discharging)
        #expect(s.isExternalPowerConnected == false)
        // The power-source estimate wins over the registry's AvgTimeToEmpty (339).
        #expect(s.timeToEmptyMinutes == 342)
        #expect(s.timeToFullMinutes == nil)

        // macOS 27 keeps mAh values in BatteryData.
        #expect(s.currentCapacityMAh == 3901)
        #expect(s.fullChargeCapacityMAh == 5862)
        #expect(s.nominalChargeCapacityMAh == 6006)
        #expect(s.designCapacityMAh == 5760)
        #expect(s.cycleCount == 48)
        #expect(s.designCycleCount == 1000, "IOPS DesignCycleCount (300) must not win")
        #expect(s.healthCondition == "Normal")
        #expect(s.permanentFailureStatus == nil)

        #expect(s.voltageMV == 12176)
        #expect(s.amperageMA == -612)
        #expect(s.instantAmperageMA == -612)
        // Not exposed on macOS 27.
        #expect(s.cellVoltagesMV.isEmpty)
        #expect(s.temperatureCelsius == nil)

        #expect(s.adapter == nil)
        #expect(s.notChargingReason == 0x80)
        #expect(s.slowChargingReason == 0)
        #expect(s.systemPowerInMW == 0)
        #expect(s.systemLoadMW == 7499)
        #expect(s.adapterEfficiencyLossMW == 0)
        #expect(s.isLowPowerModeEnabled == false)

        #expect(s.deviceName == "bq40z651")
        #expect(s.manufacturer == nil)
        #expect(s.serialNumber == "REDACTED")
    }

    @Test func m5Charging() throws {
        let s = try Fixture.m5Charging.snapshot()

        #expect(s.chargePercent == 70)
        #expect(s.chargeState == .charging)
        #expect(s.isExternalPowerConnected == true)
        // IOPS says -1 (calculating) and AvgTimeToFull is 65535; AvgTimeToEmpty (403) is valid
        // but must be ignored while charging.
        #expect(s.timeToFullMinutes == nil)
        #expect(s.timeToEmptyMinutes == nil)
        #expect(s.currentCapacityMAh == 3896)
        #expect(s.fullChargeCapacityMAh == 5866)
        #expect(s.amperageMA == 384)

        let adapter = try #require(s.adapter)
        #expect(adapter.watts == 60)
        #expect(adapter.voltageMV == 20000, "IOPS adapter details only have AdapterVoltage")
        #expect(adapter.currentMA == 2990)
        #expect(adapter.name == "40W Pwr Adapter 60W Max")
        #expect(adapter.manufacturer == "Apple Inc.")
        #expect(adapter.adapterDescription == "pd charger")
        #expect(adapter.serialNumber == "REDACTED")
        #expect(adapter.isWireless == false)

        #expect(s.notChargingReason == 0)
        #expect(s.chargingCurrentMA == nil, "ChargerData no longer has ChargingCurrent")
        #expect(s.systemPowerInMW == 18545)
        #expect(s.systemLoadMW == 13974)
        #expect(s.adapterEfficiencyLossMW == 453)
    }

    @Test func legacyAppleSiliconLayout() throws {
        let s = try Fixture.legacyDischarging.snapshot()

        #expect(s.chargePercent == 87)
        #expect(s.chargeState == .discharging)
        #expect(s.timeToEmptyMinutes == 291)
        #expect(s.currentCapacityMAh == 5051)
        #expect(s.fullChargeCapacityMAh == 5807)
        #expect(s.nominalChargeCapacityMAh == 6024)
        #expect(s.designCapacityMAh == 6249)
        #expect(s.cycleCount == 214)
        #expect(s.healthCondition == "Good")
        #expect(s.permanentFailureStatus == 0)
        #expect(s.amperageMA == -1024)
        #expect(s.instantAmperageMA == -1061)
        #expect(s.cellVoltagesMV == [4144, 4143, 4146])
        #expect(s.temperatureCelsius == 31.12)
        #expect(s.manufacturer == "SMP")
        #expect(s.serialNumber == "F8Y0000SYNTHETIC")
    }

    @Test func legacyAppleSiliconCharging() throws {
        let s = try Fixture.legacyCharging.snapshot()

        #expect(s.chargeState == .charging)
        #expect(s.timeToFullMinutes == 52)
        // IOPSCopyExternalPowerAdapterDetails is preferred over the registry copy.
        #expect(s.adapter?.watts == 96)
        #expect(s.adapter?.serialNumber == "C4H0000SYNTHETIC")
        #expect(s.chargingCurrentMA == 4000)
        #expect(s.chargingVoltageMV == 13050)
    }

    @Test func conditionDefaultsToNormalOnlyWithPowerSourceData() {
        func condition(_ ps: PropertyDictionary) -> String? {
            BatteryReading(smartBattery: [:], powerSource: ps, timestamp: Fixture.timestamp).snapshot.healthCondition
        }
        #expect(condition([:]) == nil)
        #expect(condition(["Type": .string("InternalBattery")]) == "Normal")
        #expect(condition(["BatteryHealthCondition": .string("Service Recommended")]) == "Service Recommended")
    }

    @Test func rawCaptureRoundTrips() throws {
        let reading = try Fixture.m5Charging.reading()
        let reparsed = BatteryReading(rawCapture: reading.rawCapture, timestamp: Fixture.timestamp)
        #expect(reparsed == reading)
    }

    @Test func redactionMatchesKeysWhateverTheValueType() {
        let capture: PropertyDictionary = [
            "AppleSmartBattery": .dictionary([
                "FirmwareSerialNumber": .int(48879),
                "ManufacturerData": .data(Data([0xDE, 0xAD])),
                "Cells": .array([.array([.dictionary(["SerialString": .string("X1")])])]),
                "CycleCount": .int(12),
            ]),
            "AdapterDetails": .dictionary(["SerialNumber": .int(12_345_678), "Watts": .int(96)]),
        ]
        let redacted = BatteryReading.redactingSerialNumbers(in: capture)
        let battery = redacted["AppleSmartBattery"]?.dictionaryValue
        #expect(battery?["FirmwareSerialNumber"] == .string("REDACTED"))
        #expect(battery?["ManufacturerData"] == .string("REDACTED"))
        #expect(battery?["Cells"] == .array([.array([.dictionary(["SerialString": .string("REDACTED")])])]))
        #expect(battery?["CycleCount"] == .int(12))
        #expect(redacted["AdapterDetails"]?.dictionaryValue?["SerialNumber"] == .string("REDACTED"))
        #expect(redacted["AdapterDetails"]?.dictionaryValue?["Watts"] == .int(96))
    }

    @Test func staleAdapterIsIgnoredOnBattery() {
        let adapter: PropertyDictionary = ["Watts": .int(96), "Name": .string("96W USB-C Power Adapter")]
        let s = BatteryReading(
            smartBattery: ["ExternalConnected": .bool(false), "AdapterDetails": .dictionary(adapter)],
            adapterDetails: adapter,
            timestamp: Fixture.timestamp
        ).snapshot
        #expect(s.chargeState == .discharging)
        #expect(s.adapter == nil)
    }

    @Test func timeToEmptyOnlyWhileDischarging() {
        let s = BatteryReading(
            smartBattery: [
                "ExternalConnected": .bool(true), "IsCharging": .bool(false), "AvgTimeToEmpty": .int(120),
            ],
            powerSource: ["Time to Empty": .int(120)],
            timestamp: Fixture.timestamp
        ).snapshot
        #expect(s.chargeState == .notCharging)
        #expect(s.timeToEmptyMinutes == nil)
    }

    @Test func timeToFullOnlyWhileCharging() {
        let s = BatteryReading(
            smartBattery: ["ExternalConnected": .bool(false), "AvgTimeToFull": .int(60)],
            powerSource: ["Time to Full Charge": .int(60)],
            timestamp: Fixture.timestamp
        ).snapshot
        #expect(s.chargeState == .discharging)
        #expect(s.timeToFullMinutes == nil)
    }

    @Test func integerPercentagesStayExact() {
        for value in 0...100 {
            #expect(MacPowerParser.percent(value, of: 100) == Double(value))
        }
        #expect(MacPowerParser.percent(150, of: 100) == 100)
    }

    @Test func redactedCaptureHidesSerialNumbers() throws {
        let reading = try Fixture.legacyCharging.reading()
        let redacted = BatteryReading(rawCapture: reading.redactedRawCapture, timestamp: Fixture.timestamp)
        #expect(redacted.adapterDetails["SerialString"] == .string("REDACTED"))
        #expect(redacted.snapshot.adapter?.serialNumber == "REDACTED")
        // Everything else survives.
        #expect(redacted.snapshot.adapter?.watts == 96)
        #expect(redacted.snapshot.cycleCount == reading.snapshot.cycleCount)

        let discharging = try Fixture.legacyDischarging.reading()
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

    @Test func emptyInputsProduceEmptySnapshot() {
        let s = BatteryReading(smartBattery: [:], timestamp: Fixture.timestamp).snapshot
        #expect(s == BatterySnapshot(timestamp: Fixture.timestamp))
    }
}

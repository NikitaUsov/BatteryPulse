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
        #expect(!s.isTimeRemainingCalculating)
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

    /// Captured by 0.3, which also walks the registry children and reads the SMC.
    @Test func m5OnBatteryWithChildrenAndSMC() throws {
        let reading = try Fixture.m5OnBatterySMC.reading()
        let s = reading.snapshot

        #expect(s.chargePercent == 47)
        #expect(s.chargeState == .discharging)
        #expect(s.timeToEmptyMinutes == 214)
        #expect(s.currentCapacityMAh == 2618)
        #expect(s.fullChargeCapacityMAh == 5863)
        #expect(s.nominalChargeCapacityMAh == 6007)
        #expect(s.cycleCount == 49)
        // The SMC's live readings; the registry's last gauge update agrees within a few units.
        #expect(s.voltageMV == 11501)
        #expect(s.amperageMA == -720)
        #expect(s.instantAmperageMA == -713)
        // From AppleSmartBatteryPack and the three AppleSmartBatteryBank entries; they add up to
        // the pack voltage.
        #expect(s.temperatureCelsius == 33.69)
        #expect(s.cellVoltagesMV == [3837, 3836, 3837])
        #expect(s.cellVoltagesMV.reduce(0, +) == 11510)
        // From AppleChargerData: the gauge asks for 4.47 V per cell even while discharging.
        #expect(s.chargingCurrentMA == 0)
        #expect(s.chargingVoltageMV == 4470)
        #expect(s.notChargingReason == 0x80)
        #expect(s.systemLoadMW == 8321)

        // The SMC agrees with the registry: the same cells, and B0AT in tenths of a kelvin.
        let smc = try #require(reading.rawCapture[BatteryReading.CaptureKey.smc]?.dictionaryValue)
        #expect(SMCBattery.cellVoltagesMV(in: smc, packVoltageMV: s.voltageMV) == [3836, 3836, 3833])
        #expect(SMCBattery.temperatureCelsius(in: smc) == 33.75)
        var withoutRegistry = reading.smartBattery
        withoutRegistry[RegistryChildren.childrenKey] = nil
        let fallback = BatteryReading(smartBattery: withoutRegistry, smc: smc, timestamp: Fixture.timestamp).snapshot
        #expect(fallback.cellVoltagesMV == [3836, 3836, 3833])
        #expect(fallback.temperatureCelsius == 33.75)
    }

    /// Ten seconds after plugging in, macOS still reports "not charging" with the discharge
    /// current, but the SMC already measures the charge current.
    @Test func m5JustPluggedInChargesAtOnce() throws {
        let reading = try Fixture.m5PluggedIn10s.reading()
        #expect(reading.powerSource["Is Charging"] == .bool(false))
        #expect(reading.smartBattery["Amperage"] == .int(-679))
        let s = reading.snapshot
        #expect(s.isExternalPowerConnected == true)
        #expect(s.chargeState == .charging)
        #expect(s.isTimeRemainingCalculating)
        #expect(s.timeToFullMinutes == nil)
        #expect(s.amperageMA == 1898)
        #expect(s.voltageMV == 11860)
        #expect(try abs(#require(s.batteryPowerWatts) - 22.51) < 0.01)
        #expect(s.adapter?.watts == 35)
        // Without the SMC (the widget) the registry's state stands.
        let registryOnly = BatteryReading(
            smartBattery: reading.smartBattery, powerSource: reading.powerSource,
            adapterDetails: reading.adapterDetails, timestamp: Fixture.timestamp
        ).snapshot
        #expect(registryOnly.chargeState == .notCharging)
        #expect(registryOnly.amperageMA == -679)
    }

    /// Just after unplugging, the registry still shows a charge current.
    @Test func m5JustUnpluggedDischarges() throws {
        let s = try Fixture.m5Unplugged.snapshot()
        #expect(s.chargeState == .discharging)
        #expect(s.isTimeRemainingCalculating)
        #expect(s.amperageMA == -562)
        #expect(s.voltageMV == 11702)
        #expect(try #require(s.batteryPowerWatts) < 0)
    }

    @Test func liveChargeCurrentNeedsAnAdapterAndNoHold() throws {
        let charging = SMCBattery.capture([
            SMCRawValue(key: "B0AV", info: SMCTests.ui16, payload: [0x54, 0x2E]),
            SMCRawValue(
                key: "B0AC", info: SMCKeyInfo(size: 2, type: "si16", attributes: 0x84), payload: [0x6A, 0x07]),
        ])
        func state(_ ps: PropertyDictionary, _ sb: PropertyDictionary = ["ExternalConnected": .bool(true)])
            -> ChargeState
        {
            BatteryReading(smartBattery: sb, powerSource: ps, smc: charging, timestamp: Fixture.timestamp)
                .snapshot.chargeState
        }
        #expect(state(["Is Charging": .bool(false)]) == .charging)
        #expect(
            state(["Is Charging": .bool(false), "Optimized Battery Charging Engaged": .bool(true)]) == .notCharging)
        #expect(
            state(["Is Charging": .bool(false)], ["ExternalConnected": .bool(true), "FullyCharged": .bool(true)])
                == .charged)
        #expect(state(["Is Charging": .bool(false)], ["ExternalConnected": .bool(false)]) == .discharging)
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
        #expect(s.isTimeRemainingCalculating)
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
        // USB-PD menu of the real 60 W adapter: 5/9/15/20 V at ~3 A, 20 V negotiated.
        #expect(adapter.profiles.map(\.voltageMV) == [5000, 9000, 15000, 20000])
        #expect(adapter.profiles.map(\.maxCurrentMA) == [2960, 2970, 2980, 2990])
        #expect(adapter.activeProfile == PowerProfile(index: 3, voltageMV: 20000, maxCurrentMA: 2990))
        #expect(abs(try #require(adapter.activeProfile).maxWatts - 59.8) < 0.0001)
        #expect(s.gaugeUpdatedAt == Date(timeIntervalSince1970: 1_791_994_651))

        #expect(s.notChargingReason == 0)
        #expect(s.chargingCurrentMA == nil, "ChargerData no longer has ChargingCurrent")
        #expect(s.systemPowerInMW == 18545)
        #expect(s.systemLoadMW == 13974)
        #expect(s.adapterEfficiencyLossMW == 1631, "453 µWh per one-second sample")
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
        #expect(condition(["BatteryHealthCondition": .string("")]) == "Normal")
        #expect(condition(["BatteryHealthCondition": .string(""), "BatteryHealth": .string("Good")]) == "Good")
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

    @Test func calculatingIsDistinctFromMissing() {
        // -1 from IOPS: macOS is calculating; the gauge's average must not stand in.
        let calculating = MacPowerParser.timeRemaining(powerSource: .int(-1), gauge: .int(403))
        #expect(calculating.0 == nil)
        #expect(calculating.calculating)
        // No IOPS value at all: fall back to the gauge.
        let missing = MacPowerParser.timeRemaining(powerSource: nil, gauge: .int(403))
        #expect(missing.0 == 403)
        #expect(!missing.calculating)
        let zero = MacPowerParser.timeRemaining(powerSource: .int(0), gauge: .int(65535))
        #expect(zero.0 == nil)
        #expect(!zero.calculating)
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

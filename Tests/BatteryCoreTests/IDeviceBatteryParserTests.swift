import Foundation
import Testing

@testable import BatteryCore

/// All inputs are SYNTHETIC (see ``SyntheticIDevice``): no real iOS capture exists yet.
@Suite struct IDeviceBatteryParserTests {
    @Test func iOS26iPhone() throws {
        let b = try #require(IDeviceBatteryParser.battery(in: SyntheticIDevice.iPhoneCapture))

        #expect(b.source == "AppleSmartBattery")
        #expect(b.chargePercent == 9)
        #expect(b.chargeState == .charging)
        #expect(b.isExternalPowerConnected == true)
        #expect(b.currentCapacityMAh == 219)
        #expect(b.fullChargeCapacityMAh == 2633, "AppleRawMaxCapacity before iOS 27")
        #expect(b.nominalChargeCapacityMAh == 2564)
        #expect(b.designCapacityMAh == 3092)
        #expect(b.maximumCapacityPercent == nil, "no key publishes it; never calculated")
        #expect(b.cycleCount == 768)
        #expect(b.designCycleCount == nil)
        #expect(b.temperatureCelsius == 35.5)
        #expect(b.voltageMV == 3879, "Voltage 0 falls back to AppleRawBatteryVoltage")
        #expect(b.amperageMA == 1476)
        #expect(b.instantAmperageMA == 1460)
        #expect(b.cellVoltagesMV == [3879])
        #expect(b.adapter?.watts == 12)
        #expect(b.adapter?.adapterDescription == "usb host")
        #expect(b.errorCondition == nil)
        #expect(b.permanentFailureStatus == nil)

        #expect(abs(try #require(b.nominalToDesignPercent) - 82.924) < 0.001)
        #expect(abs(try #require(b.fullChargeToDesignPercent) - 85.155) < 0.001)
        #expect(abs(try #require(b.batteryPowerWatts) - 5.7254) < 0.001)
    }

    @Test func iPadOS27MovedCapacitiesAndTemperature() throws {
        let b = try #require(IDeviceBatteryParser.battery(in: SyntheticIDevice.iPadCapture))

        #expect(b.chargePercent == 81, "CurrentCapacity / MaxCapacity without the lockdown domain")
        #expect(b.chargeState == .charging)
        #expect(b.designCapacityMAh == 7544)
        #expect(b.nominalChargeCapacityMAh == 7913)
        #expect(b.fullChargeCapacityMAh == nil)
        #expect(b.currentCapacityMAh == nil)
        #expect(b.temperatureCelsius == 33.5, "from the pack's BatteryData")
        #expect(b.voltageMV == 4164)
        #expect(b.cycleCount == 11)
        // A new battery holds more than its design capacity; the ratio is not capped.
        #expect(abs(try #require(b.nominalToDesignPercent) - 104.891) < 0.001)
        #expect(b.fullChargeToDesignPercent == nil)
    }

    @Test func bothRatiosArePinned() throws {
        let b = try #require(IDeviceBatteryParser.battery(entry: SyntheticIDevice.agedIPadEntry))
        #expect(abs(try #require(b.nominalToDesignPercent) - 90.719) < 0.001)
        #expect(abs(try #require(b.fullChargeToDesignPercent) - 88.204) < 0.001)
        #expect(b.maximumCapacityPercent == nil)
    }

    @Test func missingKeysStayNil() throws {
        let b = try #require(IDeviceBatteryParser.battery(entry: ["DesignCapacity": .int(3000)]))
        #expect(b == IDeviceBatteryParser.battery(entry: ["DesignCapacity": .int(3000)]))
        #expect(b.designCapacityMAh == 3000)
        #expect(b.chargePercent == nil)
        #expect(b.chargeState == .unknown)
        #expect(b.isExternalPowerConnected == nil)
        #expect(b.currentCapacityMAh == nil)
        #expect(b.fullChargeCapacityMAh == nil)
        #expect(b.nominalChargeCapacityMAh == nil)
        #expect(b.cycleCount == nil)
        #expect(b.temperatureCelsius == nil)
        #expect(b.voltageMV == nil)
        #expect(b.amperageMA == nil)
        #expect(b.cellVoltagesMV.isEmpty)
        #expect(b.adapter == nil)
        #expect(b.nominalToDesignPercent == nil)
        #expect(b.batteryPowerWatts == nil)
    }

    @Test func noCapacityIsNoBattery() {
        #expect(IDeviceBatteryParser.battery(entry: [:]) == nil)
        #expect(IDeviceBatteryParser.battery(entry: ["CurrentCapacity": .int(50), "MaxCapacity": .int(100)]) == nil)
        #expect(
            IDeviceBatteryParser.battery(entry: [
                "DesignCapacity": .int(0), "NominalChargeCapacity": .int(0), "AppleRawMaxCapacity": .int(0),
            ]) == nil)
        #expect(IDeviceBatteryParser.battery(in: IDeviceCapture()) == nil)
    }

    @Test func zeroCapacityFallsThroughToTheNextKey() throws {
        let entry: PropertyDictionary = [
            "BatteryData": .dictionary(["DesignCapacity": .int(0)]), "DesignCapacity": .int(3092),
        ]
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).designCapacityMAh == 3092)
    }

    @Test func temperatureFallbacks() throws {
        var entry = SyntheticIDevice.iPhoneEntry
        entry["Temperature"] = .int(0)  // no reading
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).temperatureCelsius == 34.2)

        entry["VirtualTemperature"] = .int(65535)  // 655 °C: not a reading
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).temperatureCelsius == nil)

        entry["Temperature"] = nil
        entry["VirtualTemperature"] = nil
        let pack: PropertyDictionary = ["BatteryData": .dictionary(["Temperature": .int(2950)])]
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry, pack: pack)).temperatureCelsius == 29.5)
    }

    @Test func voltageFallbacks() throws {
        var entry = SyntheticIDevice.iPhoneEntry
        entry["AppleRawBatteryVoltage"] = .int(0)
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).voltageMV == nil, "0 is no reading")
        let pack: PropertyDictionary = ["BatteryData": .dictionary(["Voltage": .int(3901)])]
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry, pack: pack)).voltageMV == 3901)
    }

    @Test func lockdownChargeWinsWhenValid() throws {
        let entry = SyntheticIDevice.iPadEntry
        let shown = try #require(
            IDeviceBatteryParser.battery(entry: entry, lockdown: ["BatteryCurrentCapacity": .int(80)]))
        #expect(shown.chargePercent == 80)
        let bogus = try #require(
            IDeviceBatteryParser.battery(entry: entry, lockdown: ["BatteryCurrentCapacity": .int(250)]))
        #expect(bogus.chargePercent == 81)
    }

    @Test func lockdownFillsMissingFlags() throws {
        let entry: PropertyDictionary = ["DesignCapacity": .int(3000)]
        let b = try #require(
            IDeviceBatteryParser.battery(entry: entry, lockdown: SyntheticIDevice.iPhoneLockdownBattery))
        #expect(b.chargePercent == 9)
        #expect(b.isExternalPowerConnected == true)
        #expect(b.chargeState == .charging)
    }

    @Test func dischargingAndFull() throws {
        var entry = SyntheticIDevice.iPadEntry
        entry["IsCharging"] = .bool(false)
        entry["ExternalConnected"] = .bool(false)
        entry["Amperage"] = .int(-350)
        let discharging = try #require(IDeviceBatteryParser.battery(entry: entry))
        #expect(discharging.chargeState == .discharging)
        #expect(discharging.amperageMA == -350)
        #expect(try #require(discharging.batteryPowerWatts) < 0)

        entry["ExternalConnected"] = .bool(true)
        entry["FullyCharged"] = .bool(true)
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).chargeState == .charged)
    }

    /// `MaximumCapacityPercent` has not been seen in an iOS registry; if a device publishes it,
    /// it is shown as is, and only when it is a plausible percentage.
    @Test func maximumCapacityOnlyFromItsKey() throws {
        var entry = SyntheticIDevice.agedIPadEntry
        entry["MaximumCapacityPercent"] = .int(91)
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).maximumCapacityPercent == 91)
        entry["MaximumCapacityPercent"] = .int(0)
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).maximumCapacityPercent == nil)
    }

    /// `ErrorCondition` and `PermanentFailureStatus` are what Apple's AppleSmartBattery driver
    /// source sets when the gauge reports a fault.
    @Test func healthKeysWhenPresent() throws {
        var entry = SyntheticIDevice.agedIPadEntry
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).errorCondition == nil)
        entry["ErrorCondition"] = .string("Cell Check Fault")
        entry["PermanentFailureStatus"] = .int(0x10)
        let b = try #require(IDeviceBatteryParser.battery(entry: entry))
        #expect(b.errorCondition == "Cell Check Fault")
        #expect(b.permanentFailureStatus == 0x10)
        entry["ErrorCondition"] = .string("")
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).errorCondition == nil)
    }

    @Test func noAdapterOnBattery() throws {
        var entry = SyntheticIDevice.iPhoneEntry
        entry["AppleRawExternalConnected"] = .bool(false)
        entry["IsCharging"] = .bool(false)
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).adapter == nil)
    }

    @Test func implausibleCellVoltagesAreDropped() throws {
        var entry = SyntheticIDevice.iPhoneEntry
        entry["BatteryData"] = .dictionary(["CellVoltage": .array([.int(0), .int(3901), .int(65535)])])
        #expect(try #require(IDeviceBatteryParser.battery(entry: entry)).cellVoltagesMV == [3901])
    }

    @Test func iOSTemperatureIsCentidegrees() {
        #expect(IDeviceBatteryParser.celsius(fromCentidegrees: 2809) == 28.09)
        #expect(IDeviceBatteryParser.celsius(fromCentidegrees: 0) == nil)
        #expect(IDeviceBatteryParser.celsius(fromCentidegrees: -4500) == nil)
        #expect(IDeviceBatteryParser.celsius(fromCentidegrees: 15_100) == nil)
    }

    @Test func codableRoundTrip() throws {
        let b = try #require(IDeviceBatteryParser.battery(in: SyntheticIDevice.iPhoneCapture))
        let decoded = try JSONDecoder().decode(IDeviceBattery.self, from: JSONEncoder().encode(b))
        #expect(decoded == b)
    }
}

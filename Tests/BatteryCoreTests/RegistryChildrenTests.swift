import Foundation
import Testing

@testable import BatteryCore

/// The child entries are shaped like MacDashboard's fixture, "trimmed from a real
/// `ioreg -r -c AppleSmartBattery -a -l` capture on macOS 27".
struct RegistryChildrenTests {
    static func bank(_ id: Int, _ millivolts: Int) -> [String: Any] {
        ["IOObjectClass": "AppleSmartBatteryBank", "BankID": id, "BatteryData": ["CellVoltage": millivolts]]
    }

    static func smartBattery(banks: [[String: Any]] = [bank(2, 4101), bank(0, 4098), bank(1, 4095)])
        -> PropertyDictionary
    {
        let pack: [String: Any] = [
            "IOObjectClass": "AppleSmartBatteryPack",
            "BatteryData": ["Temperature": 2789, "VirtualTemperature": 2801],
            "IORegistryEntryChildren": banks,
        ]
        let charger: [String: Any] = [
            "IOObjectClass": "AppleChargerData",
            "ChargerData": ["ChargingCurrent": 2990, "ChargingVoltage": 13_050],
        ]
        let dictionary: [String: Any] = [
            "Voltage": 12_294,
            "ChargerData": ["NotChargingReason": 0, "ChargingCurrent": 0],
            "IORegistryEntryChildren": [pack, charger],
        ]
        return PropertyValue.dictionary(fromAny: dictionary) ?? [:]
    }

    @Test func listsEveryDescendantDepthFirst() {
        let entries = RegistryChildren.entries(in: Self.smartBattery())
        #expect(
            entries.map(\.className) == [
                "AppleSmartBatteryPack", "AppleSmartBatteryBank", "AppleSmartBatteryBank", "AppleSmartBatteryBank",
                "AppleChargerData",
            ])
        #expect(entries[1].path == ["AppleSmartBatteryPack", "AppleSmartBatteryBank"])
        #expect(
            entries.allSatisfy {
                $0.properties["IOObjectClass"] == nil && $0.properties["IORegistryEntryChildren"] == nil
            })
    }

    @Test func readsPackTemperatureAndBankVoltages() {
        let sb = Self.smartBattery()
        #expect(RegistryChildren.temperatureCelsius(in: sb) == 27.89)
        #expect(RegistryChildren.cellVoltagesMV(in: sb) == [4098, 4095, 4101])
        #expect(RegistryChildren.chargerData(in: sb)["ChargingCurrent"] == .int(2990))
    }

    @Test func dropsIncompleteOrImplausibleValues() {
        // One bank without a voltage: no cells rather than a partial list.
        let partial = Self.smartBattery(banks: [
            Self.bank(0, 4098), ["IOObjectClass": "AppleSmartBatteryBank", "BankID": 1],
        ])
        #expect(RegistryChildren.cellVoltagesMV(in: partial) == [])
        let implausible = Self.smartBattery(banks: [Self.bank(0, 65_535)])
        #expect(RegistryChildren.cellVoltagesMV(in: implausible) == [])
        #expect(RegistryChildren.temperatureCelsius(in: [:]) == nil)
        #expect(RegistryChildren.cellVoltagesMV(in: [:]) == [])
    }

    @Test func parserUsesTheChildren() {
        let s = BatteryReading(smartBattery: Self.smartBattery(), timestamp: Fixture.timestamp).snapshot
        #expect(s.temperatureCelsius == 27.89)
        #expect(s.cellVoltagesMV == [4098, 4095, 4101])
        #expect(s.cellVoltageSpreadMV == 6)
        // The charger's own entry wins over the stale top-level ChargerData.
        #expect(s.chargingCurrentMA == 2990)
        #expect(s.chargingVoltageMV == 13_050)
        #expect(s.notChargingReason == 0)
    }

    @Test func topLevelValuesStillWinOnOlderReleases() {
        var sb = Self.smartBattery()
        sb["Temperature"] = .int(3050)
        sb["CellVoltage"] = .array([.int(4000), .int(4001), .int(4002)])
        let s = BatteryReading(smartBattery: sb, timestamp: Fixture.timestamp).snapshot
        #expect(s.temperatureCelsius == 30.5)
        #expect(s.cellVoltagesMV == [4000, 4001, 4002])
    }

    @Test func smcIsTheLastResort() {
        let smc = SMCBattery.capture([
            SMCTests.cell("BC1V", 4100), SMCTests.cell("BC2V", 4098), SMCTests.cell("BC3V", 4096),
        ])
        let sb: PropertyDictionary = ["Voltage": .int(12_294)]
        let s = BatteryReading(smartBattery: sb, smc: smc, timestamp: Fixture.timestamp).snapshot
        #expect(s.cellVoltagesMV == [4100, 4098, 4096])
        let children = BatteryReading(smartBattery: Self.smartBattery(), smc: smc, timestamp: Fixture.timestamp)
        #expect(children.snapshot.cellVoltagesMV == [4098, 4095, 4101])
    }

    @Test func realM5CapturesHaveNoChildrenYet() throws {
        // The checked-in M5 captures predate the children walk: nothing changes for them.
        let reading = try Fixture.m5Charging.reading()
        #expect(RegistryChildren.entries(in: reading.smartBattery).isEmpty)
        #expect(reading.snapshot.temperatureCelsius == nil)
    }

    @Test func rawDataShowsEachChildAndTheSMC() throws {
        let smc = SMCBattery.capture([SMCTests.cell("BC1V", 4100)])
        let reading = BatteryReading(smartBattery: Self.smartBattery(), smc: smc, timestamp: Fixture.timestamp)
        let sections = RawSection.sections(for: reading.rawCapture)
        #expect(
            sections.map(\.title) == [
                "AppleSmartBattery", "AppleSmartBatteryPack", "AppleSmartBatteryBank 1", "AppleSmartBatteryBank 2",
                "AppleSmartBatteryBank 3", "AppleChargerData", "AppleSMC",
            ])
        #expect(Set(sections.map(\.id)).count == sections.count)
        #expect(Set(sections.flatMap(\.rows).map(\.id)).count == sections.flatMap(\.rows).count)
        // The children aren't repeated inside the AppleSmartBattery section.
        #expect(sections[0].rows.allSatisfy { !$0.path.hasPrefix("IORegistryEntryChildren") })

        let pack = try #require(sections.first { $0.title == "AppleSmartBatteryPack" })
        let temperature = try #require(pack.rows.first { $0.path == "BatteryData.Temperature" })
        #expect(temperature.key == "AppleSmartBatteryPack.BatteryData.Temperature")
        #expect(temperature.decoded == .celsius(27.89))
        let bank = try #require(sections.first { $0.title == "AppleSmartBatteryBank 1" })
        #expect(bank.rows.first { $0.path == "BatteryData.CellVoltage" }?.decoded == .millivolts(4101))
        #expect(bank.rows.first { $0.path == "BankID" }?.info != nil)
        let charger = try #require(sections.first { $0.title == "AppleChargerData" })
        #expect(charger.rows.first { $0.path == "ChargerData.ChargingCurrent" }?.decoded == .milliamps(2990))

        let smcRow = try #require(sections.last?.rows.first)
        #expect(smcRow.key == "SMC.BC1V")
        #expect(smcRow.property == .int(4100))
        #expect(smcRow.decoded == .millivolts(4100))
    }
}

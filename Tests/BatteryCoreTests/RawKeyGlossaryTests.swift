import BatteryCore
import Foundation
import Testing

@Suite struct RawKeyGlossaryTests {
    /// Real captures with the registry entries below AppleSmartBattery.
    static let capturesWithChildren: [Fixture] = [.m5OnBatterySMC, .m5PluggedIn10s, .m5Unplugged]

    /// Keys of the entries below AppleSmartBattery in the real captures that the glossary still
    /// leaves unexplained, because no source or consistency check backs a meaning. A new capture
    /// with more keys, or a new entry, changes this list.
    @Test func unexplainedChildEntryKeys() throws {
        var unexplained: Set<String> = []
        for fixture in Fixture.allCases where !fixture.rawValue.hasPrefix("synthetic-") {
            let sections = RawSection.sections(for: try fixture.reading().rawCapture)
            for section in sections where section.id.hasPrefix(BatteryReading.CaptureKey.smartBattery + "/") {
                unexplained.formUnion(section.rows.filter { $0.info?.summary == nil }.map(\.key))
            }
        }
        #expect(
            unexplained.sorted() == [
                "AppleSmartBatteryBank.BatteryData.CellWom",
                "AppleSmartBatteryCell.CellData.CellCurrent",
                "AppleSmartBatteryCell.CellData.CellDisconnect",
                "AppleSmartBatteryPack.BatteryData.BatteryHealthMetric",
                "AppleSmartBatteryPack.BatteryData.BatteryPfCommsFailure",
                "AppleSmartBatteryPack.BatteryData.BatteryState",
                "AppleSmartBatteryPack.BatteryData.Dod0AtQualifiedQmax",
                "AppleSmartBatteryPack.BatteryData.FaultType",
                "AppleSmartBatteryPack.BatteryData.Flags",
                "AppleSmartBatteryPack.BatteryData.IPDBatteryDemand",
                "AppleSmartBatteryPack.BatteryData.ITMiscStatus",
                "AppleSmartBatteryPack.BatteryData.IdealCRate",
                "AppleSmartBatteryPack.BatteryData.MiscStatus",
                "AppleSmartBatteryPack.BatteryData.QmaxDisqualificationReason",
                "AppleSmartBatteryPack.BatteryData.Qstart",
                "AppleSmartBatteryPack.BatteryData.ResScale",
                "AppleSmartBatteryPack.BatteryData.SimRate",
                "AppleSmartBatteryPack.BatteryData.Soc1Voltage",
                "AppleSmartBatteryPack.BatteryData.VmaxNcc",
                "AppleSmartBatteryPack.BatteryData.iMaxAndSocSmoothTable",
            ])
    }

    /// The pack's values that the glossary calls copies match the values they copy, in every
    /// state captured: on battery, just plugged in and just unplugged.
    @Test(arguments: capturesWithChildren)
    func packCopiesMatchTheTopLevel(fixture: Fixture) throws {
        let smartBattery = try fixture.reading().smartBattery
        let pack = try #require(
            RegistryChildren.entries(in: smartBattery).first { $0.className == RegistryChildren.packClass })
        let packData = try #require(pack.properties["BatteryData"]?.dictionaryValue)
        let topData = try #require(smartBattery["BatteryData"]?.dictionaryValue)
        #expect(packData["Amperage"] == smartBattery["Amperage"])
        #expect(packData["InstantAmperage"] == smartBattery["InstantAmperage"])
        #expect(packData["AppleRawBatteryVoltage"] == smartBattery["Voltage"])
        #expect(packData["AppleRawBatteryVoltage"] == smartBattery["AppleRawBatteryVoltage"])
        #expect(packData["AppleRawCurrentCapacity"] == topData["RemainingCapacity"])
        #expect(packData["AppleRawMaxCapacity"] == topData["FullChargeCapacity"])
        // Six ASCII digits that read backwards as YYMMDD from 1992: 33-11-11 is 2025-11-11.
        let date = try #require(packData["ManufactureDate"]?.intValue)
        let ascii = withUnsafeBytes(of: UInt64(date).bigEndian) { Array($0.drop { $0 == 0 }) }
        #expect(String(decoding: ascii.reversed(), as: UTF8.self) == "331111")
    }

    /// A class-specific entry explains only its own registry entry; a plain one every entry.
    @Test func childKeysPreferTheirClassEntry() throws {
        let rows = RawSection.sections(for: try Fixture.m5OnBatterySMC.reading().rawCapture).flatMap(\.rows)
        let amperage = try #require(rows.first { $0.key == "AppleSmartBatteryPack.BatteryData.Amperage" })
        #expect(amperage.decoded == .milliamps(-713))
        #expect(amperage.info?.summary?.hasPrefix("Copy of Amperage") == true)
        #expect(RawKeyGlossary.info(for: "BatteryData.Amperage") == nil)

        let ids = rows.filter { $0.path == "ID" }
        #expect(ids.map(\.key) == ["AppleSmartBatteryPack.ID", "AppleChargerData.ID"])
        #expect(ids.allSatisfy { $0.info != nil && $0.info == RawKeyGlossary.info(for: "ID") })
        let cellBanks = rows.filter { $0.key == "AppleSmartBatteryCell.BankID" }
        #expect(cellBanks.count == 6)
        #expect(cellBanks.allSatisfy { $0.info == RawKeyGlossary.info(for: "BankID") })
    }
}

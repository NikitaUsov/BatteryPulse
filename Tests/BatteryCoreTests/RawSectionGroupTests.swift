import BatteryCore
import Foundation
import Testing

@Suite struct RawSectionGroupTests {
    private func sections(_ fixture: Fixture) throws -> [RawSection] {
        RawSection.sections(for: try fixture.reading().redactedRawCapture)
    }

    /// Plugged in, a real capture has every kind of dictionary; on battery the adapter's is empty,
    /// so its choice goes.
    @Test func realCapturesOfferTheirGroupsInTableOrder() throws {
        #expect(RawSectionGroup.groups(in: try sections(.m5PluggedIn10s)) == RawSectionGroup.allCases)
        #expect(
            RawSectionGroup.groups(in: try sections(.m5OnBatterySMC)) == [
                .battery, .pack, .banks, .charger, .powerSources, .smc,
            ])
    }

    @Test(arguments: Fixture.allCases)
    func everySectionHasAGroup(fixture: Fixture) throws {
        for section in try sections(fixture) {
            #expect(RawSectionGroup(sectionID: section.id) != nil, "\(section.id)")
        }
    }

    /// The groups follow the table: filtering never reorders, and the groups split the table
    /// without overlap or gaps.
    @Test func groupsPartitionTheTable() throws {
        let all = try sections(.m5PluggedIn10s)
        let regrouped = RawSectionGroup.allCases.flatMap { RawSectionGroup.sections(all, in: $0) }
        #expect(regrouped.map(\.id) == all.map(\.id))
        #expect(RawSectionGroup.sections(all, in: nil) == all)
    }

    @Test func banksIncludeTheirCells() throws {
        let banks = RawSectionGroup.sections(try sections(.m5OnBatterySMC), in: .banks)
        let titles = banks.map(\.title)
        #expect(titles.filter { $0.hasPrefix(RegistryChildren.bankClass) }.count == 3)
        #expect(titles.contains { $0.hasPrefix("AppleSmartBatteryCell") })
        #expect(titles.allSatisfy { $0.hasPrefix(RegistryChildren.bankClass) || $0.hasPrefix("AppleSmartBatteryCell") })
        #expect(titles.first?.hasPrefix(RegistryChildren.bankClass) == true)
    }

    @Test func singleEntryGroups() throws {
        let all = try sections(.m5PluggedIn10s)
        #expect(RawSectionGroup.sections(all, in: .battery).map(\.title) == ["AppleSmartBattery"])
        #expect(RawSectionGroup.sections(all, in: .pack).map(\.title) == [RegistryChildren.packClass])
        #expect(RawSectionGroup.sections(all, in: .charger).map(\.title) == [RegistryChildren.chargerClass])
        #expect(RawSectionGroup.sections(all, in: .powerSources).map(\.title) == ["IOPowerSources"])
        #expect(
            RawSectionGroup.sections(all, in: .adapter).map(\.title) == ["IOPSCopyExternalPowerAdapterDetails"])
        #expect(RawSectionGroup.sections(all, in: .smc).map(\.title) == ["AppleSMC"])
    }

    /// The legacy layout has no registry children and no SMC.
    @Test func legacyCaptureHasOnlyTheTopLevelDictionaries() throws {
        let groups = RawSectionGroup.groups(in: try sections(.legacyCharging))
        #expect(groups.first == .battery)
        #expect(!groups.contains(.pack))
        #expect(!groups.contains(.banks))
        #expect(!groups.contains(.smc))
    }

    /// Demo Mode's dictionaries are grouped like real ones.
    @Test func demoReadingHasGroups() throws {
        let battery = try #require(DemoScenario.charging.battery)
        let reading = battery.reading(at: Fixture.timestamp)
        let sections = RawSection.sections(for: reading.redactedRawCapture)
        let groups = RawSectionGroup.groups(in: sections)
        #expect(groups.first == .battery)
        #expect(groups.contains(.powerSources))
        #expect(sections.allSatisfy { RawSectionGroup(sectionID: $0.id) != nil })
    }

    @Test func sectionIDs() {
        let prefix = BatteryReading.CaptureKey.smartBattery + "/"
        #expect(RawSectionGroup(sectionID: BatteryReading.CaptureKey.smartBattery) == .battery)
        #expect(RawSectionGroup(sectionID: prefix + "AppleSmartBatteryPack#1") == .pack)
        #expect(RawSectionGroup(sectionID: prefix + "AppleSmartBatteryPack/AppleSmartBatteryBank#2") == .banks)
        #expect(
            RawSectionGroup(
                sectionID: prefix + "AppleSmartBatteryPack/AppleSmartBatteryBank/AppleSmartBatteryCell#5") == .banks)
        #expect(RawSectionGroup(sectionID: prefix + "AppleChargerData#1") == .charger)
        // An entry of a class the app doesn't know stays with the battery it belongs to.
        #expect(RawSectionGroup(sectionID: prefix + "IORegistryEntry#1") == .battery)
        #expect(RawSectionGroup(sectionID: BatteryReading.CaptureKey.powerSource) == .powerSources)
        #expect(RawSectionGroup(sectionID: BatteryReading.CaptureKey.adapterDetails) == .adapter)
        #expect(RawSectionGroup(sectionID: BatteryReading.CaptureKey.smc) == .smc)
        #expect(RawSectionGroup(sectionID: "Something") == nil)
        #expect(RawSectionGroup(sectionID: "AppleSmartBatteryPack") == nil)
    }
}

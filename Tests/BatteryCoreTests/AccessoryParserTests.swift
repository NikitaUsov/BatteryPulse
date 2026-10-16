import Foundation
import Testing

@testable import BatteryCore

@Suite struct AccessoryParserTests {
    private typealias Key = AccessoryParser.Key

    private func accessory(_ name: String) throws -> AccessoryBattery {
        try #require(try AccessoryFixture.synthetic.accessories().first { $0.name == name })
    }

    private func source(
        _ name: String, part: String? = nil, category: String? = "Headphone", percent: Int64 = 50,
        state: String = "Battery Power", charging: Bool = false
    ) -> PropertyDictionary {
        var source: PropertyDictionary = [
            Key.type: .string(Key.accessorySourceType), Key.name: .string(name),
            Key.currentCapacity: .int(percent), Key.maxCapacity: .int(100), Key.state: .string(state),
            Key.isCharging: .bool(charging), Key.transport: .string("Bluetooth"),
        ]
        if let part { source[Key.partIdentifier] = .string(part) }
        if let category { source[Key.category] = .string(category) }
        return source
    }

    @Test func filtersOtherTypesAndInvalidEntries() throws {
        let accessories = try AccessoryFixture.synthetic.accessories()
        #expect(accessories.count == 8)
        let names = Set(accessories.map(\.name))
        for dropped in ["InternalBattery-0", "Test UPS", "Absent Keyboard", "Silent Mouse"] {
            #expect(!names.contains(dropped), "\(dropped)")
        }
        #expect(names.contains("Backup Keyboard"), "a source without Type is kept")
    }

    @Test func groupsPartsByGroupIdentifier() throws {
        let buds = try accessory("Test Buds")
        #expect(buds.parts.map(\.role) == [.left, .right, .case])
        #expect(buds.parts.map(\.percent) == [64, 61, 90])
        #expect(buds.kind == .headphones)
        #expect(buds.transport == .bluetooth)
        #expect(buds.hasParts)
        #expect(buds.symbolName == "airpods")
    }

    @Test func caseCategoryMakesACasePart() throws {
        #expect(AccessoryPartRole(partIdentifier: nil, category: "Audio Battery Case") == .case)
        #expect(AccessoryPartRole(partIdentifier: "", category: "Audio Battery Case") == .case)
        #expect(AccessoryPartRole(partIdentifier: nil, category: "Headphone") == .single)
        #expect(AccessoryPartRole(partIdentifier: "Lid", category: nil) == .other)
        let casePart = try #require(try accessory("Test Buds").parts.last)
        #expect(casePart.role == .case)
        #expect(casePart.isCharging)
        #expect(casePart.isOnExternalPower)
    }

    @Test func loneCombinedPartShowsAsSingle() throws {
        let headset = try accessory("Test Headset")
        #expect(headset.parts == [AccessoryPart(role: .combined, percent: 45)])
        #expect(!headset.hasParts)
        #expect(headset.symbolName == "headphones")
        #expect(headset.kind == .headphones)
    }

    @Test func percentUsesMaxCapacity() throws {
        #expect(try accessory("Generic Mouse").parts.map(\.percent) == [70])

        func percent(current: PropertyValue, max: PropertyValue?) -> Int? {
            var source: PropertyDictionary = [Key.currentCapacity: current]
            source[Key.maxCapacity] = max
            return AccessoryParser.part(from: source)?.percent
        }
        #expect(percent(current: .int(7), max: .int(10)) == 70)
        #expect(percent(current: .int(2), max: .int(3)) == 67)
        #expect(percent(current: .int(42), max: .int(100)) == 42)
        #expect(percent(current: .int(42), max: nil) == 42)
        #expect(percent(current: .int(42), max: .int(0)) == 42)
        #expect(percent(current: .double(41.6), max: nil) == 42)
        #expect(percent(current: .int(130), max: nil) == 100)
        #expect(percent(current: .int(-1), max: .int(100)) == nil)
        #expect(percent(current: .string("50"), max: .int(100)) == nil)
    }

    @Test func chargingAcceptsBooleanOrNumber() throws {
        let trackpad = try accessory("Studio Trackpad")
        #expect(trackpad.kind == .trackpad)
        #expect(trackpad.transport == .usb)
        #expect(
            trackpad.parts == [AccessoryPart(role: .single, percent: 54, isCharging: true, isOnExternalPower: true)])
        #expect(trackpad.level == AccessoryLevel(percent: 54, isCharging: true))
    }

    @Test func offlinePartKeepsLastValue() throws {
        let controller = try #require(try AccessoryFixture.synthetic.accessories().first { $0.kind == .gameController })
        #expect(controller.name.isEmpty)
        #expect(controller.parts == [AccessoryPart(role: .single, percent: 30, isOffline: true)])
        #expect(controller.level == nil)
    }

    @Test(arguments: [
        ("Keyboard" as String?, AccessoryKind.keyboard),
        ("Mouse", .mouse),
        ("Trackpad", .trackpad),
        ("Headphone", .headphones),
        ("Headset", .headphones),
        ("Audio Battery Case", .headphones),
        ("Speaker", .speaker),
        ("Game Controller", .gameController),
        ("HearingAid", .hearingAid),
        ("Watch", .other),
        ("Pencil", .other),
        ("Battery Case", .other),
        ("Unknown", .other),
        ("Gizmo", .other),
        (nil, .other),
    ])
    func categoriesMapToKinds(category: String?, kind: AccessoryKind) {
        #expect(AccessoryKind(category: category) == kind)
    }

    @Test func everyKindHasASymbol() {
        for kind in AccessoryKind.allCases {
            #expect(!kind.symbolName.isEmpty)
        }
        #expect(AccessoryKind.other.symbolName == AccessoryKind.fallbackSymbolName)
        #expect(AccessoryPartRole.single.symbolName == nil)
        #expect(AccessoryPartRole.case.symbolName == "airpods.chargingcase")
    }

    @Test func transports() {
        #expect(AccessoryTransport("Bluetooth") == .bluetooth)
        #expect(AccessoryTransport("Bluetooth LE") == .bluetoothLE)
        #expect(AccessoryTransport("USB") == .usb)
        #expect(AccessoryTransport("Inductive In-Band") == .other)
        #expect(AccessoryTransport(nil).displayName == nil)
        #expect(AccessoryTransport.bluetoothLE.displayName == "Bluetooth LE")
    }

    @Test func sortsByKindThenName() throws {
        let sources = try AccessoryFixture.synthetic.sources()
        let expected: [AccessoryKind] = [
            .keyboard, .keyboard, .mouse, .trackpad, .headphones, .headphones, .gameController, .other,
        ]
        let accessories = AccessoryParser.accessories(from: sources)
        #expect(accessories.map(\.kind) == expected)
        #expect(accessories.prefix(2).map(\.name) == ["Backup Keyboard", "Desk Keyboard"])
        #expect(accessories[4..<6].map(\.name) == ["Test Buds", "Test Headset"])

        var generator = SplitMix64(seed: 2026)
        for _ in 0..<20 {
            let shuffled = AccessoryParser.accessories(from: sources.shuffled(using: &generator))
            #expect(shuffled.map(\.id) == accessories.map(\.id))
        }
    }

    @Test func idsAreStableAndOpaque() throws {
        let sources = try AccessoryFixture.synthetic.sources()
        let first = AccessoryParser.accessories(from: sources)
        #expect(AccessoryParser.accessories(from: sources).map(\.id) == first.map(\.id))
        #expect(Set(first.map(\.id)).count == first.count)

        var secrets: Set<String> = []
        for source in sources {
            for key in [Key.name, Key.groupIdentifier, Key.accessoryIdentifier] {
                if let value = source[key]?.stringValue, !value.isEmpty { secrets.insert(value) }
            }
        }
        for accessory in first {
            #expect(accessory.id.hasPrefix("acc-"))
            #expect(accessory.id.count == 20)
            #expect(!secrets.contains { accessory.id.contains($0) })
        }
        #expect(AccessoryParser.stableID(for: "") == "acc-cbf29ce484222325")
        #expect(AccessoryParser.stableID(for: "a") == "acc-af63dc4c8601ec8c")
    }

    @Test func partsWithoutGroupIdentifierGroupByName() {
        let accessories = AccessoryParser.accessories(from: [
            source("Buds", part: "Right", percent: 70),
            source("Buds", category: "Audio Battery Case", percent: 30, state: "AC Power", charging: true),
            source("Buds", part: "Left", percent: 72),
            source("Other Buds", part: "Left", percent: 10),
        ])
        #expect(accessories.count == 2)
        let buds = accessories[0]
        #expect(buds.name == "Buds")
        #expect(buds.parts.map(\.role) == [.left, .right, .case])
        #expect(buds.parts.map(\.percent) == [72, 70, 30])
        #expect(accessories[1].name == "Other Buds")
    }

    @Test func nameComesFromTheEarbudsNotTheCase() {
        var budsCase = source("Buds Case", category: "Audio Battery Case", percent: 90)
        var left = source("Buds", part: "Left", percent: 60)
        budsCase[Key.groupIdentifier] = .string("group-1")
        left[Key.groupIdentifier] = .string("group-1")
        // The case is published first, and its name says "Case".
        let accessories = AccessoryParser.accessories(from: [budsCase, left])
        #expect(accessories.map(\.name) == ["Buds"])
        #expect(accessories.first?.parts.map(\.role) == [.left, .case])
        // A lone case keeps its own name.
        #expect(AccessoryParser.accessories(from: [budsCase]).map(\.name) == ["Buds Case"])
    }

    @Test func sharedRoleKeepsTheFirstPart() {
        let accessories = AccessoryParser.accessories(from: [
            source("Buds", part: "Left", percent: 40), source("Buds", part: "Left", percent: 90),
        ])
        #expect(accessories.map(\.parts) == [[AccessoryPart(role: .left, percent: 40)]])
    }

    @Test func groupingKeyFallsBackInOrder() {
        func key(_ values: PropertyDictionary) -> String? { AccessoryParser.groupingKey(values) }
        let name: PropertyDictionary = [Key.name: .string("Mouse")]
        #expect(key(name.merging([Key.groupIdentifier: .string("G")]) { $1 }) == "g:G")
        #expect(key(name.merging([Key.accessoryIdentifier: .string("A")]) { $1 }) == "a:A")
        #expect(key(name.merging([Key.vendorID: .int(1), Key.productID: .int(2)]) { $1 }) == "p:Mouse|1|2")
        #expect(
            key(name.merging([Key.vendorID: .int(0xffff), Key.productID: .int(2), Key.powerSourceID: .int(9)]) { $1 })
                == "s:9")
        #expect(key(name.merging([Key.groupIdentifier: .string("")]) { $1 }) == nil)
        #expect(key([Key.partIdentifier: .string("Case"), Key.name: .string("Buds")]) == "n:Buds")
    }

    /// A source tied only by its per-boot `Power Source ID` keeps its id when powerd numbers it
    /// again (a reboot or a reconnect), so its alert doesn't fire a second time.
    @Test func perBootSourceKeepsItsIDAcrossReads() {
        func mouse(_ number: Int64, percent: Int64 = 8) -> PropertyDictionary {
            source("Mouse", category: "Mouse", percent: percent).merging([Key.powerSourceID: .int(number)]) { $1 }
        }
        let before = AccessoryParser.accessories(from: [mouse(9)])
        let after = AccessoryParser.accessories(from: [mouse(42)])
        #expect(before.count == 1)
        #expect(before.map(\.id) == after.map(\.id))

        var state = AccessoryAlertState()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(AccessoryAlerts.evaluate(before, threshold: 20, now: start, state: &state).fired.count == 1)
        #expect(AccessoryAlerts.evaluate(after, threshold: 20, now: start + 60, state: &state).fired.isEmpty)

        // Two that say the same about themselves stay apart, ranked by their numbers.
        let twins = AccessoryParser.accessories(from: [mouse(11, percent: 70), mouse(10)])
        let renumbered = AccessoryParser.accessories(from: [mouse(30), mouse(31, percent: 70)])
        #expect(Set(twins.map(\.id)).count == 2)
        #expect(Set(twins.map(\.id)) == Set(renumbered.map(\.id)))
        #expect(twins.first { $0.parts.first?.percent == 8 }?.id == before.first?.id)
        #expect(renumbered.first { $0.parts.first?.percent == 8 }?.id == before.first?.id)
    }

    @Test func levelIgnoresTheCase() throws {
        #expect(try accessory("Test Buds").level == AccessoryLevel(percent: 61, isCharging: false))
        let loneCase = AccessoryBattery(
            id: "acc-1", name: "Buds", kind: .headphones, transport: .bluetooth,
            parts: [AccessoryPart(role: .case, percent: 5)])
        #expect(loneCase.level == nil)
        #expect(loneCase.hasParts)
    }

    @Test func levelUsesTheDrainingBud() {
        func level(_ parts: [AccessoryPart]) -> AccessoryLevel? {
            AccessoryBattery(id: "acc-1", name: "", kind: .headphones, transport: .bluetooth, parts: parts).level
        }
        #expect(
            level([
                AccessoryPart(role: .left, percent: 18),
                AccessoryPart(role: .right, percent: 70, isCharging: true, isOnExternalPower: true),
            ]) == AccessoryLevel(percent: 18, isCharging: false))
        #expect(
            level([
                AccessoryPart(role: .left, percent: 40, isCharging: true),
                AccessoryPart(role: .right, percent: 30, isOnExternalPower: true),
            ]) == AccessoryLevel(percent: 30, isCharging: true))
    }
}

/// A seeded generator, so a failing shuffle can be replayed.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}

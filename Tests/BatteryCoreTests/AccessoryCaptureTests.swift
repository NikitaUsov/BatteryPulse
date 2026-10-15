import Foundation
import Testing

@testable import BatteryCore

@Suite struct AccessoryCaptureTests {
    private typealias Key = AccessoryParser.Key

    /// What a redacted capture must keep: everything but the name and the id.
    private struct Shape: Hashable {
        var kind: AccessoryKind
        var transport: AccessoryTransport
        var parts: [AccessoryPart]

        init(_ accessory: AccessoryBattery) {
            kind = accessory.kind
            transport = accessory.transport
            parts = accessory.parts
        }
    }

    private func xml(_ capture: PropertyDictionary) throws -> String {
        let data = try PropertyListSerialization.data(
            fromPropertyList: PropertyValue.dictionary(capture).foundationValue, format: .xml, options: 0)
        return String(decoding: data, as: UTF8.self)
    }

    private func readBack(_ capture: PropertyDictionary) throws -> AccessoryReading {
        let data = try PropertyListSerialization.data(
            fromPropertyList: PropertyValue.dictionary(capture).foundationValue, format: .xml, options: 0)
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        let raw = try #require(PropertyValue.dictionary(fromAny: root))
        return try #require(AccessoryReading(rawCapture: raw))
    }

    private func fixture(_ name: String) throws -> PropertyDictionary {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "plist", subdirectory: "Fixtures"))
        let root = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(PropertyValue.dictionary(fromAny: root))
    }

    @Test func rawCaptureRoundTripsThroughAPropertyList() throws {
        let reading = try AccessoryFixture.synthetic.reading()
        let copy = try readBack(reading.rawCapture)
        #expect(copy.accessories == reading.accessories)
        #expect(copy == reading)
    }

    @Test func redactionKeepsGrouping() throws {
        let reading = try AccessoryFixture.synthetic.reading()
        let redacted = try readBack(reading.redactedRawCapture)
        #expect(redacted.accessories.count == reading.accessories.count)
        #expect(Set(redacted.accessories.map(Shape.init)) == Set(reading.accessories.map(Shape.init)))
        // Numbered by the order in which each accessory's first source appears; the internal
        // battery is the first source and the game controller's empty name stays empty.
        #expect(
            Set(redacted.accessories.map(\.name)) == [
                "Accessory 2", "Accessory 3", "Accessory 4", "Accessory 5", "Accessory 6", "Accessory 7", "",
                "Accessory 9",
            ])
        let buds = try #require(redacted.accessories.first { $0.name == "Accessory 5" })
        #expect(buds.parts.map(\.role) == [.left, .right, .case])
    }

    @Test func redactionPseudonymizesConsistently() throws {
        let capture = try AccessoryFixture.synthetic.reading().redactedRawCapture
        let sources = try #require(capture[AccessoryReading.CaptureKey.sources]?.arrayValue).compactMap(
            \.dictionaryValue)
        let buds = sources.filter { $0[Key.groupIdentifier] != nil && $0[Key.name] == .string("Accessory 5") }
        #expect(buds.count == 3)
        #expect(Set(buds.compactMap { $0[Key.groupIdentifier] }) == [.string("group-1")])
        #expect(
            buds.compactMap { $0[Key.accessoryIdentifier]?.stringValue } == [
                "accessory-2", "accessory-3", "accessory-4",
            ])
        #expect(
            buds.compactMap { $0[Key.partName]?.stringValue } == [
                "Accessory 5 Left", "Accessory 5 Right", "Accessory 5",
            ])
        let headset = try #require(sources.first { $0[Key.partIdentifier] == .string("Combined") })
        let combined = try #require(headset[Key.combinedParts]?.arrayValue).compactMap(\.dictionaryValue)
        #expect(combined.compactMap { $0[Key.partName]?.stringValue } == ["Accessory 6 Left", "Accessory 6 Right"])
        #expect(combined.compactMap { $0[Key.accessoryIdentifier]?.stringValue } == ["accessory-6", "accessory-7"])
        let keyboard = try #require(sources.first { $0[Key.name] == .string("Accessory 2") })
        #expect(keyboard["Hardware Serial Number"] == .string("REDACTED"))
        #expect(keyboard[Key.vendorID] == .int(4660))
        #expect(keyboard[Key.powerSourceID] == .int(101))
    }

    @Test func redactionRemovesIdentifiers() throws {
        let reading = try AccessoryFixture.synthetic.reading()
        var secrets: Set<String> = []
        func collect(_ source: PropertyDictionary) {
            for key in [
                Key.name, Key.partName, Key.groupIdentifier, Key.accessoryIdentifier, "Hardware Serial Number",
                "Address",
            ] {
                if let value = source[key]?.stringValue, !value.isEmpty { secrets.insert(value) }
            }
            for part in source[Key.combinedParts]?.arrayValue ?? [] {
                if let part = part.dictionaryValue { collect(part) }
            }
        }
        reading.sources.forEach(collect)
        #expect(secrets.count > 20)

        let text = try xml(reading.redactedRawCapture)
        for secret in secrets {
            #expect(!text.contains(secret), "\(secret)")
        }
        #expect(text.contains("REDACTED"))
        #expect(try xml(reading.rawCapture).contains("Test Buds"))
    }

    @Test func emptyCaptureIsAccepted() throws {
        let reading = try #require(AccessoryReading(rawCapture: [AccessoryReading.CaptureKey.sources: .array([])]))
        #expect(reading.accessories.isEmpty)
        #expect(reading.redactedRawCapture == [AccessoryReading.CaptureKey.sources: .array([])])
    }

    @Test func rejectsOtherCaptures() throws {
        #expect(AccessoryReading(rawCapture: try fixture(Fixture.m5OnBattery.rawValue)) == nil)
        #expect(AccessoryReading(rawCapture: try fixture(RealIDeviceCaptureTests.iPhone17ProMax)) == nil)
        #expect(AccessoryReading(rawCapture: [AccessoryReading.CaptureKey.sources: .array([.string("x")])]) == nil)
        #expect(AccessoryReading(rawCapture: [AccessoryReading.CaptureKey.sources: .string("x")]) == nil)
        #expect(IDeviceCapture(rawCapture: try AccessoryFixture.synthetic.raw()) == nil)
    }
}

import BatteryCore
import Foundation
import Testing

@testable import bpulse

/// The JSON `bpulse` prints for scripts, rendered from every capture in BatteryCoreTests' fixtures
/// as `bpulse --input <capture> --json` would: a Mac's snapshot and a device's battery carry
/// `formatVersion` 1 and ISO 8601 dates; the accessory list stays a bare array.
@Suite struct JSONOutputTests {
    static let fixtureFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("BatteryCoreTests/Fixtures")

    static let fixtureNames: [String] = {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: fixtureFolder.path)) ?? []
        return names.filter { $0.hasSuffix(".plist") }.map { String($0.dropLast(".plist".count)) }.sorted()
    }()

    static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

    /// The capture's kind, decided as `bpulse --input` decides it.
    enum Capture {
        case mac(BatteryReading)
        case device(IDeviceCapture)
        case accessories(AccessoryReading)
    }

    static func capture(_ name: String) throws -> Capture {
        let data = try Data(contentsOf: fixtureFolder.appendingPathComponent(name + ".plist"))
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        let raw = try #require(PropertyValue.dictionary(fromAny: root))
        if let device = IDeviceCapture(rawCapture: raw) { return .device(device) }
        if let accessories = AccessoryReading(rawCapture: raw) { return .accessories(accessories) }
        return .mac(BatteryReading(rawCapture: raw, timestamp: timestamp))
    }

    static func object(_ json: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    /// The top-level keys of a pretty-printed object, in their order.
    static func topLevelKeys(_ json: String) -> [Substring] {
        json.split(separator: "\n").filter { $0.hasPrefix("  \"") }.map { $0.dropFirst(3).prefix { $0 != "\"" } }
    }

    static func expectVersionedObject(_ json: String) throws {
        let keys = topLevelKeys(json)
        #expect(keys.count > 5)
        #expect(keys == keys.sorted())
        #expect(keys.contains("formatVersion"))
        #expect(try object(json)["formatVersion"] as? Int == 1)
    }

    /// Every kind of capture is among the fixtures, so the tests below see each JSON form.
    @Test func fixturesCoverEveryForm() throws {
        var kinds: Set<String> = []
        for name in Self.fixtureNames {
            switch try Self.capture(name) {
            case .mac: kinds.insert("mac")
            case .device: kinds.insert("device")
            case .accessories: kinds.insert("accessories")
            }
        }
        #expect(kinds == ["mac", "device", "accessories"])
    }

    /// `--json`, and each line of `--watch --json`.
    @Test(arguments: fixtureNames)
    func everyObjectHasTheVersion(name: String) throws {
        switch try Self.capture(name) {
        case .mac(let reading):
            try Self.expectVersionedObject(try render(reading, as: .json, compact: false))
            let line = try render(reading, as: .json, compact: true)
            #expect(!line.contains("\n"))
            #expect(try Self.object(line)["formatVersion"] as? Int == 1)
        case .device(let capture):
            try Self.expectVersionedObject(try #require(try deviceJSON(capture)))
        case .accessories(let reading):
            let json = try accessoriesJSON(reading.accessories)
            let array = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any])
            #expect(array.count == reading.accessories.count)
            #expect(!json.contains("formatVersion"))
        }
    }

    /// `--device <n> --json` writes dates as ISO 8601 strings, like `--json`; 0.6 wrote seconds
    /// since 2001 (781056000).
    @Test func deviceDatesAreISO8601() throws {
        guard case .device(let capture) = try Self.capture("iphone17promax-ios27.0.1-usb") else {
            Issue.record("not a device capture")
            return
        }
        let json = try #require(try deviceJSON(capture))
        #expect(try Self.object(json)["firstUseDate"] as? String == "2025-10-02T00:00:00Z")
    }

    /// A script written for 0.6 reads only the keys it knows and ignores `formatVersion`.
    @Test(arguments: fixtureNames)
    func oldScriptsStillRead(name: String) throws {
        struct OldScript: Decodable {
            var chargePercent: Double?
            var chargeState: String
            var cycleCount: Int?
        }
        let json: String
        switch try Self.capture(name) {
        case .mac(let reading): json = try render(reading, as: .json, compact: false)
        case .device(let capture): json = try #require(try deviceJSON(capture))
        case .accessories: return
        }
        let read = try JSONDecoder().decode(OldScript.self, from: Data(json.utf8))
        #expect(ChargeState(rawValue: read.chargeState) != nil)
        #expect(read.chargePercent != nil)
    }
}

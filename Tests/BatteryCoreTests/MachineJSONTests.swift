import BatteryCore
import Foundation
import Testing

/// `MachineJSON` adds `formatVersion` to what the stored types encode and changes nothing else:
/// the keys, the values and their order are those of a plain `JSONEncoder` with sorted keys and
/// ISO 8601 dates.
@Suite struct MachineJSONTests {
    static let iPhone = "iphone17promax-ios27.0.1-usb"

    static func plainJSON(_ value: some Encodable, compact: Bool) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = compact ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func deviceBattery() throws -> IDeviceBattery {
        let capture = try #require(IDeviceCapture(rawCapture: try fixtureDictionary(iPhone)))
        return try #require(IDeviceBatteryParser.battery(in: capture))
    }

    /// The top-level keys of a pretty-printed object, in their order.
    static func topLevelKeys(_ json: String) -> [Substring] {
        json.split(separator: "\n").filter { $0.hasPrefix("  \"") }.map { $0.dropFirst(3).prefix { $0 != "\"" } }
    }

    /// The version sorts between keys of both shapes, so it is never the last key, and its line
    /// ends with a comma.
    @Test(arguments: Fixture.allCases)
    func snapshotIsThePlainJSONPlusTheVersion(fixture: Fixture) throws {
        let snapshot = try fixture.snapshot()
        let pretty = try MachineJSON.snapshot(snapshot)
        #expect(pretty.contains("\n  \"formatVersion\" : 1,\n"))
        #expect(
            pretty.replacing("\n  \"formatVersion\" : 1,", with: "") == (try Self.plainJSON(snapshot, compact: false)))
        let compact = try MachineJSON.snapshot(snapshot, compact: true)
        #expect(!compact.contains("\n"))
        #expect(compact.contains("\"formatVersion\":1,"))
        #expect(compact.replacing("\"formatVersion\":1,", with: "") == (try Self.plainJSON(snapshot, compact: true)))
    }

    @Test func deviceBatteryIsThePlainJSONPlusTheVersion() throws {
        let battery = try Self.deviceBattery()
        let json = try MachineJSON.deviceBattery(battery)
        #expect(json.contains("\n  \"formatVersion\" : 1,\n"))
        #expect(json.replacing("\n  \"formatVersion\" : 1,", with: "") == (try Self.plainJSON(battery, compact: false)))
    }

    /// `DateOfFirstUse` 781056000 is 2025-10-02 00:00 UTC (iOS Settings showed October 2025);
    /// before 0.7, `bpulse` printed the number.
    @Test func deviceDatesAreISO8601() throws {
        let battery = try Self.deviceBattery()
        #expect(battery.firstUseDate == Date(timeIntervalSinceReferenceDate: 781_056_000))
        let json = try MachineJSON.deviceBattery(battery)
        #expect(json.contains("\n  \"firstUseDate\" : \"2025-10-02T00:00:00Z\",\n"))
    }

    @Test func formatVersionIsASortedTopLevelKey() throws {
        for json in [
            try MachineJSON.snapshot(try Fixture.m5Charging.snapshot()),
            try MachineJSON.deviceBattery(Self.deviceBattery()),
        ] {
            let keys = Self.topLevelKeys(json)
            #expect(keys.count > 5)
            #expect(keys == keys.sorted())
            #expect(keys.filter { $0 == "formatVersion" }.count == 1)
            let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            #expect(object["formatVersion"] as? Int == 1)
        }
        #expect(MachineJSON.snapshotFormatVersion == 1)
        #expect(MachineJSON.deviceBatteryFormatVersion == 1)
    }

    /// The version can't overwrite a key of the value: neither stored type has one by that name.
    @Test func storedTypesHaveNoVersionKey() throws {
        #expect(!(try Self.plainJSON(Fixture.m5Charging.snapshot(), compact: false)).contains("formatVersion"))
        #expect(!(try Self.plainJSON(Self.deviceBattery(), compact: false)).contains("formatVersion"))
    }

    /// A decoder that ignores unknown keys, as `Codable` and most scripts do, reads the output back
    /// as the value that was written.
    @Test func decodersIgnoreTheVersion() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for fixture in Fixture.allCases {
            let snapshot = try fixture.snapshot()
            for compact in [false, true] {
                let json = try MachineJSON.snapshot(snapshot, compact: compact)
                #expect(try decoder.decode(BatterySnapshot.self, from: Data(json.utf8)) == snapshot)
            }
        }
        let battery = try Self.deviceBattery()
        let json = try MachineJSON.deviceBattery(battery)
        #expect(try decoder.decode(IDeviceBattery.self, from: Data(json.utf8)) == battery)
    }

    /// Copy JSON is `bpulse --json`'s shape, for the redacted snapshot.
    @Test func copyJSONIsTheSnapshotShape() throws {
        let snapshot = try Fixture.m5Charging.snapshot()
        #expect(try snapshot.redactedJSON() == MachineJSON.snapshot(snapshot.redacted))
    }
}

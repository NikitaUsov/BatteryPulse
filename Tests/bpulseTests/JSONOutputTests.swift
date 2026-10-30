import BatteryCore
import Foundation
import Testing

@testable import bpulse

/// The JSON `bpulse` prints for scripts, rendered from the captures in BatteryCoreTests' fixtures
/// as `bpulse --input <capture> --json` would.
@Suite struct JSONOutputTests {
    static let fixtureFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("BatteryCoreTests/Fixtures")

    static func rawCapture(_ name: String) throws -> PropertyDictionary {
        let data = try Data(contentsOf: fixtureFolder.appendingPathComponent(name + ".plist"))
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(PropertyValue.dictionary(fromAny: root))
    }

    static func object(_ json: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    /// `--device <n> --json` writes dates as ISO 8601 strings, like `--json`; 0.6 wrote seconds
    /// since 2001 (781056000).
    @Test func deviceDatesAreISO8601() throws {
        let capture = try #require(IDeviceCapture(rawCapture: try Self.rawCapture("iphone17promax-ios27.0.1-usb")))
        let json = try #require(try deviceJSON(capture))
        #expect(try Self.object(json)["firstUseDate"] as? String == "2025-10-02T00:00:00Z")
    }
}

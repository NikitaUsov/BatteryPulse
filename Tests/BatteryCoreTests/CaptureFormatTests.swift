import BatteryCore
import Foundation
import Testing

@Suite struct CaptureFormatTests {
    /// Copy JSON's encoder.
    private static func copyJSON(_ snapshot: BatterySnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(snapshot), as: UTF8.self)
    }

    /// The real captures hold redacted serials. Any snapshot field fed from a key the capture
    /// redacts would carry the placeholder into Copy JSON, and the serials' own key must go.
    @Test(arguments: Fixture.allCases.filter { $0.rawValue.hasPrefix("m5-macos27-") })
    func copyJSONHasNoSerials(fixture: Fixture) throws {
        let snapshot = try fixture.snapshot()
        #expect(try Self.copyJSON(snapshot).contains("\"serialNumber\""), "the fixture has a serial to redact")
        let json = try Self.copyJSON(snapshot.redacted)
        #expect(!json.contains("REDACTED"))
        #expect(!json.contains("\"serialNumber\""))
    }
}

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

    /// A capture written in the fixture format reads back as the same dictionaries, through the
    /// property list parser `bpulse --input` uses.
    @Test(arguments: Fixture.allCases)
    func captureRoundTrips(fixture: Fixture) throws {
        let capture = try fixture.reading().redactedRawCapture
        let data = try PropertyValue.xmlPropertyListData(capture)
        #expect(data.starts(with: Data("<?xml".utf8)))
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        #expect(PropertyValue.dictionary(fromAny: root) == capture)
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

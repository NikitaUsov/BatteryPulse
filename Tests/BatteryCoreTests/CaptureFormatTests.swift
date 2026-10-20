import BatteryCore
import Foundation
import Testing

@Suite struct CaptureFormatTests {
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
    /// redacts would carry the placeholder into Copy JSON, and the serials' own key must go. The
    /// text is the one the app copies, so a change to its encoding is checked too.
    @Test(arguments: Fixture.allCases.filter { $0.rawValue.hasPrefix("m5-macos27-") })
    func copyJSONHasNoSerials(fixture: Fixture) throws {
        let snapshot = try fixture.snapshot()
        let unredacted = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        #expect(unredacted.contains("\"serialNumber\""), "the fixture has a serial to redact")
        let json = try snapshot.redactedJSON()
        #expect(!json.contains("REDACTED"))
        #expect(!json.contains("\"serialNumber\""))
        // Pretty-printed, with the top-level keys sorted.
        let keys = json.split(separator: "\n").filter { $0.hasPrefix("  \"") }.map {
            $0.dropFirst(3).prefix { $0 != "\"" }
        }
        #expect(keys.count > 5)
        #expect(keys == keys.sorted())
    }
}

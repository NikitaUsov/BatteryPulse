import Foundation
import Testing
import BatteryCore

/// Loads raw captures from `Fixtures/` (same format as `bpulse --raw`).
enum Fixture: String, CaseIterable {
    case appleSiliconDischarging = "apple-silicon-discharging"
    case appleSiliconCharging = "apple-silicon-charging"
    case intelNotCharging = "intel-not-charging"

    static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

    func reading() throws -> BatteryReading {
        let url = try #require(
            Bundle.module.url(forResource: rawValue, withExtension: "plist", subdirectory: "Fixtures")
        )
        let root = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let capture = try #require(PropertyValue.dictionary(fromAny: root))
        return BatteryReading(rawCapture: capture, timestamp: Self.timestamp)
    }

    func snapshot() throws -> BatterySnapshot {
        try reading().snapshot
    }
}

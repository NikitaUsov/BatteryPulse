import BatteryCore
import Foundation
import Testing

/// Loads raw captures from `Fixtures/` (same format as `bpulse --raw`).
enum Fixture: String, CaseIterable {
    /// Real: MacBook Air M5, macOS 27, on battery.
    case m5OnBattery = "m5-macos27-on-battery"
    /// Real: MacBook Air M5, macOS 27, charging from a 60 W adapter.
    case m5Charging = "m5-macos27-charging"
    /// Synthetic pre-macOS 27 layout, for fallback keys.
    case legacyDischarging = "synthetic-legacy-discharging"
    case legacyCharging = "synthetic-legacy-charging"

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

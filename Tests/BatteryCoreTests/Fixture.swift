import BatteryCore
import Foundation
import Testing

/// Loads raw captures from `Fixtures/` (same format as `bpulse --raw`).
enum Fixture: String, CaseIterable {
    /// Real: MacBook Air M5, macOS 27, on battery.
    case m5OnBattery = "m5-macos27-on-battery"
    /// Real: MacBook Air M5, macOS 27, charging from a 60 W adapter.
    case m5Charging = "m5-macos27-charging"
    /// Real: the same Mac, captured by BatteryPulse 0.3 with the registry children below
    /// AppleSmartBattery and the SMC's battery keys, on battery at 47 %.
    case m5OnBatterySMC = "m5-macos27-on-battery-smc"
    /// Real: the same Mac 10 s after a 35 W adapter was plugged in. macOS and the registry still
    /// say "not charging" with the discharge current; the SMC already reads the charge current.
    case m5PluggedIn10s = "m5-macos27-plugged-in-10s"
    /// Real: the same Mac just after unplugging. The registry still shows a charge current; the
    /// SMC reads the discharge current.
    case m5Unplugged = "m5-macos27-unplugged"
    /// Real: the same Mac on a 35 W adapter, held at 80 % by the Charge Limit set in System
    /// Settings → Battery: bit 24 of `NotChargingReason`, no charge current.
    case m5ChargeLimit = "m5-macos27-charge-limit"
    /// Synthetic pre-macOS 27 layout, for fallback keys.
    case legacyDischarging = "synthetic-legacy-discharging"
    case legacyCharging = "synthetic-legacy-charging"

    static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

    func reading() throws -> BatteryReading {
        BatteryReading(rawCapture: try fixtureDictionary(rawValue), timestamp: Self.timestamp)
    }

    func snapshot() throws -> BatterySnapshot {
        try reading().snapshot
    }
}

/// The capture `Fixtures/<name>.plist`: a Mac's, a device's or the accessories'.
func fixtureDictionary(_ name: String) throws -> PropertyDictionary {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "plist", subdirectory: "Fixtures"))
    let root = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
    return try #require(PropertyValue.dictionary(fromAny: root))
}

extension PowerAdapter {
    /// The negotiated USB-PD profile; the app marks it in its list by `activeProfileIndex`.
    var activeProfile: PowerProfile? {
        profiles.first { $0.index == activeProfileIndex }
    }
}

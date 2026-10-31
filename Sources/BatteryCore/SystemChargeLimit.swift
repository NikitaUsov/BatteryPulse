import Foundation

/// macOS's Charge Limit, which the user sets in System Settings → Battery → Charging (Apple silicon,
/// macOS 26.4 or later): macOS stops charging at the limit and holds the charge there. BatteryPulse
/// only reads that the limit holds the charge; it never sets a limit, and it can't read which limit
/// is set, because no IOKit or IOPS key holds the number.
///
/// Named apart from the app's own notification threshold (``AlertSettings/chargeLimit``, "When
/// charged to"), which only notifies and never stops charging.
public enum SystemChargeLimit {
    /// Bit 24 of `ChargerData.NotChargingReason`, set while the Charge Limit holds the charge.
    /// Apple doesn't document the bits. On a MacBook Air M5 with macOS 27
    /// (`m5-macos27-charge-limit.plist`), the reason went from 0 to 0x01000000 in AppleSmartBattery
    /// and in its AppleChargerData child when charging stopped at an 80 % limit; raising the limit
    /// to 100 % cleared the bit and charging resumed, and setting it back to 80 % brought it back.
    static let heldBit = 0x0100_0000
}

extension BatterySnapshot {
    /// macOS's Charge Limit holds the charge: bit 24 of `NotChargingReason`
    /// (``SystemChargeLimit``), on external power, not charging.
    ///
    /// The parser's plug-in rule runs first and turns a measured charge current into `.charging`,
    /// so a battery that charges is never at the limit. With Optimized Battery Charging's hold
    /// reported as well (never seen together), that hold wins: its flag names its cause, while bit
    /// 24 may be shared. `ChargeState` has no case of its own for the hold, since History and
    /// `bpulse --json` store the five there are.
    public var isAtSystemChargeLimit: Bool {
        guard let reason = notChargingReason, reason & SystemChargeLimit.heldBit != 0 else { return false }
        return isExternalPowerConnected == true && chargeState == .notCharging && isOptimizedChargingEngaged != true
    }
}

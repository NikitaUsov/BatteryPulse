import Foundation

/// macOS's Charge Limit, which the user sets in System Settings → Battery → Charging (Apple silicon,
/// macOS 26.4 or later): macOS stops charging at the limit and holds the charge there. BatteryPulse
/// reads that the limit holds the charge from bit 24 here, and which limit is set, a number no
/// IOKit or IOPS key holds, from powerd's charging preferences on the adapter
/// (``SystemChargeLimitSource``). It never sets a limit.
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
    /// (``SystemChargeLimit``), on external power, not charging. The widget's state word and its
    /// Charge limit field read it.
    ///
    /// A convenience for ``BatterySnapshot/notChargingCause``, whose precedence it keeps: the
    /// parser's plug-in rule runs first and turns a measured charge current into `.charging`, so a
    /// battery that charges is never at the limit, and with Optimized Battery Charging's hold
    /// reported as well (never seen together), that hold wins. `ChargeState` has no case of its
    /// own for the hold, since History and `bpulse --json` store the five there are.
    public var isAtSystemChargeLimit: Bool {
        notChargingCause == .systemChargeLimit
    }
}

/// What the Charge limit row shows, on Power and in the Battery widget's Charge limit field,
/// decided once for both so they can't drift apart: the limit's number on the adapter, and that it
/// is reached while it holds the charge. Never the charge itself, which sits within a few points
/// of the limit at the hold (macOS resumes charging only after a drop of more than 5 %).
public enum SystemChargeLimitRow: Sendable, Equatable {
    /// "80%": the limit set, on the adapter, not holding the charge.
    case limit(Int)
    /// "80%, reached": the limit holds the charge.
    case reached(Int)
    /// "Reached": the limit holds the charge, its number unknown, as 0.7 showed it.
    case reachedUnknown

    /// The row for `snapshot` with the limit `percent`: the snapshot's own in the app
    /// (``BatterySnapshot/systemChargeLimitPercent``), the feed's in the widget. `nil` hides it: on
    /// battery, and on the adapter with neither a number nor the hold.
    public init?(_ snapshot: BatterySnapshot, percent: Int?) {
        if snapshot.isAtSystemChargeLimit {
            self = percent.map(Self.reached) ?? .reachedUnknown
        } else if snapshot.isExternalPowerConnected == true, let percent {
            self = .limit(percent)
        } else {
            return nil
        }
    }
}

import Foundation

/// Why a Mac on its adapter isn't charging, for a cause a real capture proves: no capture, no
/// cause.
///
/// Each case names the capture in `Tests/BatteryCoreTests/Fixtures/` that shows it (`fixture`),
/// and comes in the commit that adds that capture, never before; `NotChargingCauseTests` checks
/// that each capture gives its case and that each case has a Demo Mode scene. Without a proven
/// cause BatteryPulse names none: beside "Not charging" the main window lists Apple's possible
/// reasons instead (``BatterySnapshot/isNotChargingWithoutCause``). Optimized Battery Charging's
/// hold, a battery that is too warm and an adapter too weak to charge wait for captures that show
/// them.
///
/// Computed from a snapshot (``BatterySnapshot/notChargingCause``) and never stored, so History,
/// `bpulse --json` and ``ChargeState``'s five cases stay as they are.
public enum NotChargingCause: Sendable, Hashable, CaseIterable {
    /// macOS's Charge Limit holds the charge: bit 24 of `NotChargingReason`
    /// (``SystemChargeLimit``).
    case systemChargeLimit

    /// The real capture that proves the cause: `Tests/BatteryCoreTests/Fixtures/<fixture>.plist`.
    var fixture: String {
        switch self {
        case .systemChargeLimit: "m5-macos27-charge-limit"
        }
    }
}

extension BatterySnapshot {
    /// Why the battery isn't charging, for a cause BatteryPulse can prove; `nil` while charging,
    /// full, on battery or unknown, and when no proven cause is reported.
    ///
    /// The precedence: the parser's plug-in rule runs first and turns a measured charge current
    /// into ``ChargeState/charging``, so a battery that charges has no cause. Then Optimized
    /// Battery Charging's flag: its hold reads "Charging on hold", and the flag names its own cause
    /// while bit 24 may be shared (the two were never seen together); it gives no case until a
    /// capture of the Mac's own battery shows the hold. Then bit 24, the Charge Limit's hold.
    public var notChargingCause: NotChargingCause? {
        guard isExternalPowerConnected == true, chargeState == .notCharging else { return nil }
        if isOptimizedChargingEngaged == true { return nil }
        if let reason = notChargingReason, reason & SystemChargeLimit.heldBit != 0 { return .systemChargeLimit }
        return nil
    }

    /// On external power, not charging and not full, with no cause BatteryPulse can prove: the
    /// state reads "Not charging", and beside it the main window offers Apple's possible reasons,
    /// naming none. Optimized Battery Charging's hold reads "Charging on hold" instead, which says
    /// why.
    public var isNotChargingWithoutCause: Bool {
        isExternalPowerConnected == true && chargeState == .notCharging && isOptimizedChargingEngaged != true
            && notChargingCause == nil
    }
}

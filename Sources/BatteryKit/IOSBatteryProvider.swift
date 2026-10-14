#if os(iOS)
import UIKit
import BatteryCore

/// Reads the battery through `UIDevice`.
///
/// iOS only exposes charge level and charging state publicly; health, cycle count and
/// electrical data are not available to App Store apps.
@MainActor
public final class IOSBatteryProvider: BatteryProvider {
    public init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    public func read() -> BatteryReading? {
        let device = UIDevice.current
        let level = device.batteryLevel
        let state = device.batteryState
        // The Simulator reports an unknown state and level -1.
        guard level >= 0 || state != .unknown else { return nil }

        var snapshot = BatterySnapshot(timestamp: Date())
        // `batteryLevel` is a Float; 0.7 would otherwise become 69.99999880…
        snapshot.chargePercent = level >= 0 ? (Double(level) * 100).rounded() : nil
        switch state {
        case .charging:
            snapshot.chargeState = .charging
            snapshot.isExternalPowerConnected = true
        case .full:
            snapshot.chargeState = .charged
            snapshot.isExternalPowerConnected = true
        case .unplugged:
            snapshot.chargeState = .discharging
            snapshot.isExternalPowerConnected = false
        case .unknown:
            snapshot.chargeState = .unknown
        @unknown default:
            snapshot.chargeState = .unknown
        }
        snapshot.applySystemState()
        return BatteryReading(snapshot: snapshot)
    }

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        let removeObservers = observeNotifications(
            [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification]
                + systemStateNotifications,
            handler: handler
        )
        return BatteryObservation(onCancel: removeObservers)
    }
}
#endif

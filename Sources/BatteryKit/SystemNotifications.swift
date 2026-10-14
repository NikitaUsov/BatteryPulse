#if canImport(Darwin)
import Foundation
import BatteryCore

/// Wraps a value that is only touched in a thread-safe way (e.g. observer tokens).
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}

extension ThermalState {
    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }
}

extension BatterySnapshot {
    /// Fills in the system-wide state shared by macOS and iOS.
    mutating func applySystemState(_ processInfo: ProcessInfo = .processInfo) {
        isLowPowerModeEnabled = processInfo.isLowPowerModeEnabled
        thermalState = ThermalState(processInfo.thermalState)
    }
}

/// Subscribes `handler` to `NotificationCenter` notifications delivered on the main queue.
/// Returns the closure that removes the observers.
@MainActor
func observeNotifications(
    _ names: [Notification.Name],
    handler: @escaping @MainActor @Sendable () -> Void
) -> @Sendable () -> Void {
    let center = NotificationCenter.default
    let tokens = names.map { name in
        center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }
    let box = UncheckedSendable(value: tokens)
    return {
        for token in box.value {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

/// Low Power Mode and thermal pressure changes, relevant on both platforms.
let systemStateNotifications: [Notification.Name] = [
    .NSProcessInfoPowerStateDidChange,
    ProcessInfo.thermalStateDidChangeNotification,
]
#endif

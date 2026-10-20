#if canImport(Darwin)
import Foundation
import BatteryCore

#if os(macOS)
import IOKit.ps
import notify
import os
#endif

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

#if os(macOS)
/// Calls `handler` on the main actor whenever one of the notify(3) keys `names` is posted, and
/// returns the closure that cancels the registrations.
///
/// notify(3) rather than `IOPSNotificationCreateRunLoopSource`: invalidating that run loop source
/// never releases its `CFMachPort`, so every stop would leak a port and a notifyd registration.
/// `notify_cancel` tears down deterministically.
@MainActor
func observeNotifyKeys(
    _ names: [String],
    handler: @escaping @MainActor @Sendable () -> Void
) -> @Sendable () -> Void {
    var tokens: [Int32] = []
    for name in names {
        var token: Int32 = 0
        let status = notify_register_dispatch(name, &token, .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        if status == 0 {
            tokens.append(token)
        } else {
            // The change would never be heard of. The keys are the code's own, so they log as public.
            Diagnostics.iokit.error("Registering for \(name, privacy: .public) failed with notify status \(status)")
        }
    }
    let registered = tokens
    return {
        for token in registered { notify_cancel(token) }
    }
}

/// The description of each power source in `info`: the blob of `IOPSCopyPowerSourcesInfo`, or of
/// another call that returns one.
func powerSourceDescriptions(in info: CFTypeRef) -> [[String: Any]] {
    let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
    return sources.compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
}
#endif

/// Low Power Mode and thermal pressure changes, relevant on both platforms.
let systemStateNotifications: [Notification.Name] = [
    .NSProcessInfoPowerStateDidChange,
    ProcessInfo.thermalStateDidChangeNotification,
]
#endif

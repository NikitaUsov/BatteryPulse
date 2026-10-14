#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import Observation
@preconcurrency import UserNotifications

/// Posts the battery notifications the user turned on in Settings → Notifications. It reacts to
/// every new reading, so it needs no polling of its own, and stays quiet during Demo Mode.
@MainActor
final class BatteryNotifier: NSObject {
    private let monitor: BatteryMonitor
    private var state: AlertState

    init(monitor: BatteryMonitor) {
        self.monitor = monitor
        state =
            UserDefaults.standard.data(forKey: AppSettings.alertStateKey)
            .flatMap { try? JSONDecoder().decode(AlertState.self, from: $0) } ?? AlertState()
        super.init()
    }

    func start() {
        UNUserNotificationCenter.current().delegate = self
        observe()
    }

    /// Re-arms on every change of the monitor's snapshot.
    private func observe() {
        withObservationTracking {
            _ = monitor.snapshot
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.evaluate()
                self?.observe()
            }
        }
    }

    private func evaluate() {
        let settings = AppSettings.alerts
        guard settings.isAnyEnabled, !monitor.isOverridden, let snapshot = monitor.snapshot else { return }
        let alerts = BatteryAlerts.evaluate(snapshot, settings: settings, state: &state)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: AppSettings.alertStateKey)
        }
        for alert in alerts {
            post(alert, snapshot)
        }
    }

    private func post(_ alert: BatteryAlert, _ snapshot: BatterySnapshot) {
        let formatter = BatteryFormatter.app
        let percent = snapshot.chargePercent.map { formatter.percent($0) } ?? ""
        let content = UNMutableNotificationContent()
        switch alert {
        case .chargeLimitReached:
            content.title = String(localized: "Battery charged to \(percent)")
            content.body = String(localized: "You can unplug the power adapter.")
        case .lowBattery:
            content.title = String(localized: "Battery low: \(percent)")
            content.body = String(localized: "Connect the power adapter soon.")
        case .serviceRecommended:
            let condition = Phrases.condition(snapshot.healthCondition) ?? ""
            content.title = String(localized: "Battery service recommended")
            content.body = String(
                localized:
                    "macOS reports the battery's condition as \(condition). It may hold less charge than when it was new."
            )
        case .highTemperature:
            content.title = String(localized: "Your Mac is running hot")
            content.body = String(
                localized:
                    "The thermal state is \(Phrases.thermal(snapshot.thermalState)). Charging may slow down until it cools."
            )
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: alert.rawValue, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Asks for permission the first time the user turns a notification on.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// A sample notification, to check how they look and that they're allowed.
    static func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "BatteryPulse notifications are on")
        content.body = String(localized: "This is how battery alerts will look.")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "test", content: content, trigger: nil))
    }
}

extension BatteryNotifier: UNUserNotificationCenterDelegate {
    /// Show alerts even while BatteryPulse is the active app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Clicking an alert opens the main window.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { WindowOpener.showMainWindow() }
    }
}
#endif

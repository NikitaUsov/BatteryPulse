#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import Observation
@preconcurrency import UserNotifications

/// Posts the battery notifications the user turned on in Settings → Notifications. It reacts to
/// every new reading of the Mac's battery and every change of the accessories, so it needs no
/// polling of its own, and stays quiet during Demo Mode.
@MainActor
final class BatteryNotifier: NSObject {
    /// UserNotifications raises an exception outside an app bundle, e.g. under
    /// `swift run BatteryPulse`, so every entry point checks this first.
    static let isAvailable = Bundle.main.bundleURL.pathExtension == "app"

    private let monitor: BatteryMonitor
    private let accessories: AccessoryMonitor
    private var state: AlertState
    private var wasPluggedIn: Bool?
    private var accessoryState: AccessoryAlertState
    /// The accessory threshold of the last evaluation, so only a change of it re-evaluates.
    private var lastAccessoryThreshold: Int?
    private var defaultsObserver: NSObjectProtocol?

    init(monitor: BatteryMonitor, accessories: AccessoryMonitor) {
        self.monitor = monitor
        self.accessories = accessories
        state =
            UserDefaults.standard.data(forKey: AppSettings.alertStateKey)
            .flatMap { try? JSONDecoder().decode(AlertState.self, from: $0) } ?? AlertState()
        accessoryState =
            UserDefaults.standard.data(forKey: AppSettings.accessoryAlertStateKey)
            .flatMap { try? JSONDecoder().decode(AccessoryAlertState.self, from: $0) } ?? AccessoryAlertState()
        super.init()
    }

    func start() {
        guard Self.isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
        observe()
        observeAccessories()
        // An accessory can stay at the same level for an hour: one that is already low at launch
        // alerts now, not at its next change.
        evaluateAccessories()
        // Turning the alert on with a mouse already below the threshold alerts at once. The
        // notifier's own writes post this notification too and end at the threshold check.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AppSettings.alerts.accessoryLowBattery != self.lastAccessoryThreshold else { return }
                self.evaluateAccessories()
            }
        }
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
        withdrawStaleAlerts(snapshot)
        let previous = state
        let alerts = BatteryAlerts.evaluate(snapshot, settings: settings, state: &state)
        // Every write posts UserDefaults.didChangeNotification, so only write real changes.
        if state != previous, let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: AppSettings.alertStateKey)
        }
        for alert in alerts {
            post(alert, snapshot)
        }
    }

    /// Re-arms on every change of the accessory list, which the monitor reassigns only when it
    /// changed.
    private func observeAccessories() {
        withObservationTracking {
            _ = accessories.accessories
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.evaluateAccessories()
                self?.observeAccessories()
            }
        }
    }

    private func evaluateAccessories() {
        let defaults = UserDefaults.standard
        let threshold = AppSettings.alerts.accessoryLowBattery
        lastAccessoryThreshold = threshold
        guard let threshold else {
            // Nothing is stored while the alert is off.
            accessoryState = AccessoryAlertState()
            if defaults.object(forKey: AppSettings.accessoryAlertStateKey) != nil {
                defaults.removeObject(forKey: AppSettings.accessoryAlertStateKey)
            }
            return
        }
        guard !accessories.isOverridden else { return }
        let previous = accessoryState
        let changes = AccessoryAlerts.evaluate(
            accessories.accessories, threshold: threshold, now: .now, state: &accessoryState)
        // Every write posts UserDefaults.didChangeNotification, so only write real changes.
        if accessoryState != previous {
            if accessoryState.firedAt.isEmpty {
                defaults.removeObject(forKey: AppSettings.accessoryAlertStateKey)
            } else if let data = try? JSONEncoder().encode(accessoryState) {
                defaults.set(data, forKey: AppSettings.accessoryAlertStateKey)
            }
        }
        // Charging, or charged past the margin: the alert no longer applies.
        if !changes.rearmed.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: changes.rearmed.map(AccessoryAlerts.notificationID(for:)))
        }
        for alert in changes.fired {
            post(alert)
        }
    }

    /// "Low Battery: Magic Mouse", "15% remaining. Charge it soon."
    private func post(_ alert: AccessoryLowBattery) {
        let name = alert.name.isEmpty ? Phrases.accessoryKind(alert.kind) : alert.name
        let percentText = BatteryFormatter.app.percent(Double(alert.percent))
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Low Battery: \(name)")
        content.body = String(localized: "\(percentText) remaining. Charge it soon.")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: AccessoryAlerts.notificationID(for: alert.id), content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// "Battery low" is moot once the adapter is connected, and "charged" once it's unplugged.
    private func withdrawStaleAlerts(_ snapshot: BatterySnapshot) {
        let pluggedIn = snapshot.isExternalPowerConnected
        defer { wasPluggedIn = pluggedIn }
        guard let pluggedIn, let wasPluggedIn, pluggedIn != wasPluggedIn else { return }
        let stale: BatteryAlert = pluggedIn ? .lowBattery : .chargeLimitReached
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [stale.rawValue])
    }

    private func post(_ alert: BatteryAlert, _ snapshot: BatterySnapshot) {
        let formatter = BatteryFormatter.app
        let percent = snapshot.chargePercent.map { formatter.percent($0) } ?? ""
        let content = UNMutableNotificationContent()
        switch alert {
        case .chargeLimitReached:
            content.title = String(localized: "Battery Charged to \(percent)")
            content.body = String(localized: "You can unplug the power adapter.")
        case .lowBattery:
            content.title = String(localized: "Low Battery: \(percent)")
            content.body = String(localized: "Connect the power adapter soon.")
        case .serviceRecommended:
            let condition = Phrases.condition(snapshot.healthCondition) ?? ""
            content.title = String(localized: "Battery Service Recommended")
            content.body = String(
                localized:
                    "macOS reports the battery's condition as \(condition). It may hold less charge than when it was new."
            )
        case .highTemperature:
            content.title = String(localized: "Your Mac Is Running Hot")
            content.body = String(
                localized:
                    "The thermal state is \(Phrases.thermal(snapshot.thermalState ?? .serious)). Charging may slow down until it cools."
            )
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: alert.rawValue, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Asks for permission the first time the user turns a notification on.
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isDenied() async -> Bool {
        guard isAvailable else { return false }
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    /// A sample notification, to check how they look and that they're allowed.
    static func sendTest() {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Notifications Are On")
        content.body = String(localized: "This is how battery alerts will look.")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "test", content: content, trigger: nil))
    }
}

extension BatteryNotifier: UNUserNotificationCenterDelegate {
    /// Show alerts even while BatteryPulse is the active app, which it is whenever Settings or
    /// the popover is open, and keep them in Notification Center.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Clicking an alert opens the main window.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { WindowOpener.showMainWindow() }
    }
}
#endif

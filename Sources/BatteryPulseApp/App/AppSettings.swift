#if os(macOS)
import AppKit
import BatteryCore
import Foundation
import Observation
import ServiceManagement
import SwiftUI

/// UserDefaults keys and launch-time decisions.
enum AppSettings {
    static let showInMenuBarKey = "showInMenuBar"
    static let showDockIconKey = "showDockIcon"
    static let menuBarStyleKey = "menuBarStyle"
    static let menuBarIconKey = "menuBarIcon"
    static let showDeveloperKey = "showDeveloperSection"
    static let showWelcomeAtLaunchKey = "showWelcomeAtLaunch"
    static let hasSeenWelcomeKey = "hasSeenWelcome"
    /// The on/off switch for update checks before 0.4; ``updateFrequencyKey`` replaced it.
    static let legacyCheckForUpdatesKey = "checkForUpdates"
    static let updateFrequencyKey = "updateFrequency"
    static let lastUpdateCheckKey = "lastUpdateCheck"
    static let skippedVersionKey = "skippedVersion"
    static let lastSeenVersionKey = "lastSeenVersion"
    static let recordHistoryKey = "recordHistory"
    static let prefersCompactWindowKey = "prefersCompactWindow"
    static let alertChargeLimitKey = "alertChargeLimit"
    static let alertLowBatteryKey = "alertLowBattery"
    static let alertServiceKey = "alertService"
    static let alertHeatKey = "alertHeat"
    static let alertStateKey = "alertState"

    static var showInMenuBar: Bool {
        UserDefaults.standard.object(forKey: showInMenuBarKey) as? Bool ?? true
    }

    static var showDockIcon: Bool {
        UserDefaults.standard.bool(forKey: showDockIconKey)
    }

    /// Percentages of 0 mean off; everything is off until the user turns it on.
    static var alerts: AlertSettings {
        let defaults = UserDefaults.standard
        let chargeLimit = defaults.integer(forKey: alertChargeLimitKey)
        let lowBattery = defaults.integer(forKey: alertLowBatteryKey)
        return AlertSettings(
            chargeLimit: chargeLimit > 0 ? chargeLimit : nil,
            lowBattery: lowBattery > 0 ? lowBattery : nil,
            serviceRecommended: defaults.bool(forKey: alertServiceKey),
            highTemperature: defaults.bool(forKey: alertHeatKey)
        )
    }

    /// Which window Open BatteryPulse, the Dock icon and a windowed launch show.
    static var prefersCompactWindow: Bool {
        UserDefaults.standard.bool(forKey: prefersCompactWindowKey)
    }

    static var recordsHistory: Bool {
        UserDefaults.standard.object(forKey: recordHistoryKey) as? Bool ?? true
    }

    /// Daily by default; Settings → General shows the choice.
    static var updateFrequency: UpdateFrequency {
        let defaults = UserDefaults.standard
        return .stored(
            defaults.string(forKey: updateFrequencyKey),
            legacyEnabled: defaults.object(forKey: legacyCheckForUpdatesKey) as? Bool)
    }

    /// Settings renamed since an earlier version keep the user's choice.
    static func migrate() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: updateFrequencyKey) == nil,
            defaults.object(forKey: legacyCheckForUpdatesKey) != nil
        {
            defaults.set(updateFrequency.rawValue, forKey: updateFrequencyKey)
            defaults.removeObject(forKey: legacyCheckForUpdatesKey)
        }
    }

    /// The welcome window always appears on first launch, later only if the user asked for it.
    static var shouldShowWelcomeAtLaunch: Bool {
        let defaults = UserDefaults.standard
        return !defaults.bool(forKey: hasSeenWelcomeKey) || defaults.bool(forKey: showWelcomeAtLaunchKey)
    }
}

/// What's New appears once after an update. Installs from before 0.3 have no recorded version,
/// so an earlier welcome window counts as 0.2.
enum WhatsNewPolicy {
    static func showsAtLaunch(current: AppVersion) -> Bool {
        let defaults = UserDefaults.standard
        let lastSeen =
            defaults.string(forKey: AppSettings.lastSeenVersionKey).flatMap(AppVersion.init)
            ?? (defaults.bool(forKey: AppSettings.hasSeenWelcomeKey) ? AppVersion(parts: [0, 2]) : nil)
        return UpdatePolicy.showsWhatsNew(lastSeen: lastSeen, current: current, features: WhatsNew.version)
    }

    /// Unversioned builds (CI artifacts share the bundle ID) don't count, or the next real
    /// release would show What's New twice.
    static func markSeen(_ version: AppVersion) {
        guard version != AppVersion(parts: [0, 0, 0]) else { return }
        UserDefaults.standard.set(version.description, forKey: AppSettings.lastSeenVersionKey)
    }
}

enum AppLinks {
    // swift-format-ignore: NeverForceUnwrap
    static let project = URL(string: "https://github.com/NikitaUsov/BatteryPulse")!
    // swift-format-ignore: NeverForceUnwrap
    static let releases = URL(string: "https://github.com/NikitaUsov/BatteryPulse/releases")!
    // swift-format-ignore: NeverForceUnwrap
    static let license = URL(string: "https://github.com/NikitaUsov/BatteryPulse/blob/main/LICENSE")!
    // swift-format-ignore: NeverForceUnwrap
    static let help = URL(string: "https://github.com/NikitaUsov/BatteryPulse/blob/main/docs/USER_GUIDE.md")!
    /// System Settings → General → Language & Region, where per-app languages are chosen.
    // swift-format-ignore: NeverForceUnwrap
    static let languageSettings = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!
    /// System Settings → Notifications.
    // swift-format-ignore: NeverForceUnwrap
    static let notificationSettings = URL(
        string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
}

/// Whether BatteryPulse shows a Dock icon.
///
/// The app is never unreachable: without the menu bar item the Dock icon always shows. With it,
/// the Dock icon is optional but appears while one of the app's windows is open, so the window
/// can be found with ⌘-Tab and macOS brings it to the front reliably.
@MainActor
enum DockIconPolicy {
    private static var openWindows: Set<String> = []

    static func windowAppeared(_ id: String) {
        openWindows.insert(id)
        apply()
    }

    static func windowDisappeared(_ id: String) {
        openWindows.remove(id)
        apply()
    }

    /// Call right before opening a window from the menu bar, so the app can come forward.
    static func prepareToShowWindow() {
        setPolicy(.regular)
    }

    static func apply() {
        let showsDock = AppSettings.showDockIcon || !AppSettings.showInMenuBar || !openWindows.isEmpty
        setPolicy(showsDock ? .regular : .accessory)
    }

    private static func setPolicy(_ policy: NSApplication.ActivationPolicy) {
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }
}

/// Opens app windows from places that have no SwiftUI environment (the Dock and its menu).
@MainActor
enum WindowOpener {
    /// Captured from any view that appears; `OpenWindowAction` works from any scene.
    static var openWindow: OpenWindowAction?

    /// The full or the compact window, whichever the user prefers.
    static func showMainWindow() {
        show(AppSettings.prefersCompactWindow ? WindowID.compact : WindowID.main)
    }

    /// Remembers the choice and opens that window; the caller closes its own.
    static func switchWindowStyle(compact: Bool) {
        UserDefaults.standard.set(compact, forKey: AppSettings.prefersCompactWindowKey)
        show(compact ? WindowID.compact : WindowID.main)
    }

    static func show(_ id: String) {
        DockIconPolicy.prepareToShowWindow()
        openWindow?(id: id)
        NSApp.activate()
    }
}

/// Registers a window for the Dock icon policy and brings the app forward when it opens.
struct TrackedWindow: ViewModifier {
    let id: String
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .onAppear {
                WindowOpener.openWindow = openWindow
                DockIconPolicy.windowAppeared(id)
                NSApp.activate()
            }
            .onDisappear { DockIconPolicy.windowDisappeared(id) }
    }
}

extension View {
    func trackedWindow(_ id: String) -> some View {
        modifier(TrackedWindow(id: id))
    }
}

/// One observable login-item state shared by every settings view, so the Welcome and Settings
/// windows can't disagree. Re-read whenever the app becomes active, since the user can also
/// change it in System Settings → General → Login Items.
@MainActor
@Observable
final class LaunchAtLoginModel {
    private(set) var isEnabled = LaunchAtLogin.isEnabled
    /// macOS registered the login item but wants the user to allow it in System Settings.
    private(set) var requiresApproval = LaunchAtLogin.requiresApproval
    private(set) var errorMessage: String?

    var isAvailable: Bool { LaunchAtLogin.isAvailable }

    func refresh() {
        isEnabled = LaunchAtLogin.isEnabled
        requiresApproval = LaunchAtLogin.requiresApproval
    }

    func set(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Login item registration through `SMAppService`.
enum LaunchAtLogin {
    /// Only a bundled app can register as a login item; `swift run` has no bundle identifier.
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
#endif

#if os(macOS)
import BatteryCore
import Foundation
import Observation
import ServiceManagement

/// UserDefaults keys and launch-time decisions.
enum AppSettings {
    static let menuBarStyleKey = "menuBarStyle"
    static let menuBarIconKey = "menuBarIcon"
    static let showWelcomeAtLaunchKey = "showWelcomeAtLaunch"
    static let hasSeenWelcomeKey = "hasSeenWelcome"

    /// The welcome window always appears on first launch, later only if the user asked for it.
    static var shouldShowWelcomeAtLaunch: Bool {
        let defaults = UserDefaults.standard
        return !defaults.bool(forKey: hasSeenWelcomeKey) || defaults.bool(forKey: showWelcomeAtLaunchKey)
    }
}

/// One observable login-item state shared by every settings view, so the Welcome and Settings
/// windows can't disagree. Re-read whenever the app becomes active, since the user can also
/// change it in System Settings → General → Login Items.
@MainActor
@Observable
final class LaunchAtLoginModel {
    private(set) var isEnabled = LaunchAtLogin.isEnabled

    var isAvailable: Bool { LaunchAtLogin.isAvailable }

    func refresh() {
        isEnabled = LaunchAtLogin.isEnabled
    }

    func set(_ enabled: Bool) {
        try? LaunchAtLogin.set(enabled)
        refresh()
    }
}

/// Login item registration through `SMAppService`.
enum LaunchAtLogin {
    /// Only a bundled app can register as a login item; `swift run` has no bundle identifier.
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
#endif

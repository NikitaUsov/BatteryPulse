#if os(macOS)
import BatteryCore
import Foundation
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

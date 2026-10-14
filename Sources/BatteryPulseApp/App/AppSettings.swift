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

    static var showInMenuBar: Bool {
        UserDefaults.standard.object(forKey: showInMenuBarKey) as? Bool ?? true
    }

    static var showDockIcon: Bool {
        UserDefaults.standard.bool(forKey: showDockIconKey)
    }

    /// The welcome window always appears on first launch, later only if the user asked for it.
    static var shouldShowWelcomeAtLaunch: Bool {
        let defaults = UserDefaults.standard
        return !defaults.bool(forKey: hasSeenWelcomeKey) || defaults.bool(forKey: showWelcomeAtLaunchKey)
    }
}

enum AppLinks {
    // swift-format-ignore: NeverForceUnwrap
    static let help = URL(string: "https://github.com/NikitaUsov/BatteryPulse/blob/main/docs/USER_GUIDE.md")!
    /// System Settings → General → Language & Region, where per-app languages are chosen.
    // swift-format-ignore: NeverForceUnwrap
    static let languageSettings = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!
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

    static func showMainWindow() {
        DockIconPolicy.prepareToShowWindow()
        openWindow?(id: WindowID.main)
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

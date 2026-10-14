#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

@main
struct BatteryPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor: BatteryMonitor
    @State private var launchAtLogin = LaunchAtLoginModel()
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    private let showsWelcome: Bool
    private let showsMainWindow: Bool

    init() {
        let monitor = BatteryMonitor(provider: MacBatteryProvider())
        monitor.start()
        _monitor = State(initialValue: monitor)
        showsWelcome = AppSettings.shouldShowWelcomeAtLaunch
        // A menu-bar app starts quietly; without the menu bar item the window is the app.
        showsMainWindow = !AppSettings.showInMenuBar
    }

    var body: some Scene {
        Window("BatteryPulse", id: WindowID.main) {
            MainView(monitor: monitor)
        }
        .defaultSize(width: 860, height: 640)
        .defaultLaunchBehavior(showsMainWindow ? .presented : .suppressed)
        .commands {
            CommandGroup(replacing: .help) {
                Button("BatteryPulse Help") { NSWorkspace.shared.open(AppLinks.help) }
            }
        }

        MenuBarExtra(isInserted: $showInMenuBar) {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to BatteryPulse", id: WindowID.welcome) {
            WelcomeView()
                .environment(launchAtLogin)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(showsWelcome ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
                .environment(launchAtLogin)
        }
    }
}

enum WindowID {
    static let main = "main"
    static let welcome = "welcome"
    static let settings = "settings"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var defaultsObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Decide on the Dock icon before anything is shown, so it doesn't flash.
        DockIconPolicy.apply()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { DockIconPolicy.apply() }
        }
    }

    /// Clicking the Dock icon with no window open brings the main window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }
        WindowOpener.showMainWindow()
        return false
    }

    /// Keeps running in the menu bar (or the Dock) after the last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(
            title: String(localized: "Open BatteryPulse"), action: #selector(openMainWindow), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openMainWindow() {
        WindowOpener.showMainWindow()
    }
}
#else
/// The app is macOS-only; this stub keeps `swift build` working on Linux.
@main
enum BatteryPulseApp {
    static func main() {
        print("BatteryPulse is a macOS app. Try `swift run bpulse` for the report.")
    }
}
#endif

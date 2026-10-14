#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

@main
struct BatteryPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor: BatteryMonitor
    @State private var demo: DemoController
    @State private var updater: UpdateChecker
    @State private var launchAtLogin = LaunchAtLoginModel()
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    private let showsWelcome: Bool
    private let showsMainWindow: Bool
    private let showsWhatsNew: Bool

    init() {
        UserDefaults.standard.register(defaults: [AppSettings.showInMenuBarKey: true])
        let monitor = BatteryMonitor(provider: MacBatteryProvider())
        monitor.start()
        // Plain assignment: in Xcode 27 @State is a macro without a public `_monitor` storage.
        self.monitor = monitor
        self.demo = DemoController(monitor: monitor)
        showsWelcome = AppSettings.shouldShowWelcomeAtLaunch
        // A menu-bar app starts quietly; without the menu bar item the window is the app.
        showsMainWindow = !AppSettings.showInMenuBar
        let updater = UpdateChecker()
        self.updater = updater
        showsWhatsNew = !showsWelcome && WhatsNewPolicy.showsAtLaunch(current: updater.currentVersion)
        WhatsNewPolicy.markSeen(updater.currentVersion)
        updater.showWindow = { WindowOpener.show(WindowID.update) }
        updater.startAutomaticChecks()
    }

    var body: some Scene {
        Window("BatteryPulse", id: WindowID.main) {
            MainView(monitor: monitor)
                .environment(demo)
        }
        .defaultSize(width: 860, height: 640)
        .defaultLaunchBehavior(showsMainWindow ? .presented : .suppressed)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkNow() }
            }
            CommandGroup(replacing: .help) {
                Button("BatteryPulse Help") { NSWorkspace.shared.open(AppLinks.help) }
                Button("What's New in BatteryPulse") { WindowOpener.show(WindowID.whatsNew) }
            }
        }

        MenuBarExtra(isInserted: $showInMenuBar) {
            PopoverView(monitor: monitor)
                .environment(demo)
                .environment(updater)
        } label: {
            MenuBarLabel(monitor: monitor)
                .environment(demo)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to BatteryPulse", id: WindowID.welcome) {
            WelcomeView()
                .environment(launchAtLogin)
                .environment(updater)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(showsWelcome ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        Window("Software Update", id: WindowID.update) {
            UpdateView()
                .environment(updater)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("What's New", id: WindowID.whatsNew) {
            WhatsNewView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(showsWhatsNew ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
                .environment(launchAtLogin)
                .environment(updater)
        }
    }
}

enum WindowID {
    static let main = "main"
    static let welcome = "welcome"
    static let settings = "settings"
    static let update = "update"
    static let whatsNew = "whatsNew"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Not in applicationWillFinishLaunching: changing the policy that early is unreliable.
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

    /// BatteryPulse keeps running when its last window closes: in the menu bar, or in the Dock
    /// when the menu bar item is off (clicking the Dock icon reopens the main window). Quitting on
    /// close would also end the app when the user turns the menu bar item off in Settings or the
    /// welcome window and then closes it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
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

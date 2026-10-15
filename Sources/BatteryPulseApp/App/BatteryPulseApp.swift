#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

@main
struct BatteryPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor: BatteryMonitor
    /// Passed to the views that use it rather than put in the environment: a view missing it is
    /// then a compile error, not a crash at run time.
    @State private var accessories: AccessoryMonitor
    @State private var demo: DemoController
    @State private var updater: UpdateChecker
    private let historyRecorder: HistoryRecorder
    private let notifier: BatteryNotifier
    private let widgetRefresher: WidgetRefresher
    @State private var launchAtLogin = LaunchAtLoginModel()
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    private let showsWelcome: Bool
    private let showsMainWindow: Bool
    private let showsWhatsNew: Bool

    init() {
        UserDefaults.standard.register(defaults: [AppSettings.showInMenuBarKey: true])
        AppSettings.migrate()
        let monitor = BatteryMonitor(provider: MacBatteryProvider())
        monitor.start()
        // Plain assignment: in Xcode 27 @State is a macro without a public `_monitor` storage.
        self.monitor = monitor
        // Always running: idle, it holds three notification registrations and no timer.
        let accessories = AccessoryMonitor(provider: SystemAccessories.makeProvider())
        accessories.start()
        self.accessories = accessories
        self.demo = DemoController(monitor: monitor, accessories: accessories)
        historyRecorder = HistoryRecorder(monitor: monitor)
        historyRecorder.start()
        AppDevices.start()
        notifier = BatteryNotifier(monitor: monitor)
        notifier.start()
        widgetRefresher = WidgetRefresher(monitor: monitor)
        widgetRefresher.start()
        showsWelcome = AppSettings.shouldShowWelcomeAtLaunch
        // A menu-bar app starts quietly; without the menu bar item the window is the app.
        showsMainWindow = !AppSettings.showInMenuBar
        // The version an in-app update replaced, and its download.
        UpdateInstaller.cleanUpAfterUpdate()
        let updater = UpdateChecker()
        self.updater = updater
        // A fresh install has no last-seen version, so What's New only follows a real update, even
        // when the welcome window opens at every launch by choice.
        showsWhatsNew = WhatsNewPolicy.showsAtLaunch(current: updater.currentVersion)
        // The first launch of another version: the previous version's widget extension may still
        // be running, and WidgetKit refuses its timelines.
        if WhatsNewPolicy.lastLaunched != updater.currentVersion {
            WidgetRefresher.endPreviousExtension()
        }
        WhatsNewPolicy.markSeen(updater.currentVersion)
        updater.showWindow = { WindowOpener.show(WindowID.update) }
        updater.startAutomaticChecks()
    }

    // Every window and the menu bar panel get `.motionPolicy()` here, outside their root view, so
    // the root view's own `@Environment(\.motion)` sees the window's policy too.
    var body: some Scene {
        Window("BatteryPulse", id: WindowID.main) {
            MainView(monitor: monitor, accessories: accessories)
                .environment(demo)
                .environment(AppDevices.monitor)
                .motionPolicy()
        }
        .defaultSize(width: 860, height: 640)
        .defaultLaunchBehavior(showsMainWindow && !AppSettings.prefersCompactWindow ? .presented : .suppressed)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BatteryPulse") { WindowOpener.show(WindowID.about) }
                Button("Check for Updates…") { updater.checkNow() }
            }
            CommandGroup(replacing: .help) {
                Button("BatteryPulse Help") { NSWorkspace.shared.open(AppLinks.help) }
                Button("What's New in BatteryPulse") { WindowOpener.show(WindowID.whatsNew) }
            }
        }

        Window("Compact Window", id: WindowID.compact) {
            CompactView(monitor: monitor)
                .environment(demo)
                .motionPolicy()
        }
        // Fixed size: the window fits its content.
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(showsMainWindow && AppSettings.prefersCompactWindow ? .presented : .suppressed)

        MenuBarExtra(isInserted: $showInMenuBar) {
            PopoverView(monitor: monitor, accessories: accessories)
                .environment(demo)
                .environment(updater)
                .motionPolicy()
        } label: {
            MenuBarLabel(monitor: monitor)
                .environment(demo)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to BatteryPulse", id: WindowID.welcome) {
            WelcomeView()
                .environment(launchAtLogin)
                .environment(updater)
                .motionPolicy()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(showsWelcome ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        Window("Software Update", id: WindowID.update) {
            UpdateView()
                .environment(updater)
                .motionPolicy()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("About BatteryPulse", id: WindowID.about) {
            AboutView()
                .environment(updater)
                .motionPolicy()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("What's New", id: WindowID.whatsNew) {
            WhatsNewView()
                .motionPolicy()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(showsWhatsNew ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
                .environment(launchAtLogin)
                .environment(updater)
                .environment(AppDevices.monitor)
                .motionPolicy()
        }
    }
}

enum WindowID {
    static let main = "main"
    static let compact = "compact"
    static let welcome = "welcome"
    static let settings = "settings"
    static let update = "update"
    static let whatsNew = "whatsNew"
    static let about = "about"
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

    /// Lets an update being installed finish, and saves the day's battery summaries (the Mac's and
    /// each iPhone's or iPad's), which are otherwise written at most hourly, before quitting.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await UpdateInstaller.current?.finishBeforeQuitting()
            try? await AppHistory.store.flush()
            await AppDevices.monitor.flushHistory()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
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

#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import BatterySource
import SwiftUI
import os

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
    /// The version that ran before this launch, for What's New's rows.
    private let previousVersion: AppVersion?

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
        notifier = BatteryNotifier(monitor: monitor, accessories: accessories)
        notifier.start()
        widgetRefresher = WidgetRefresher(monitor: monitor, accessories: accessories)
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
        previousVersion = WhatsNewPolicy.previousVersion
        // The first launch of another version, or in another language: the previous widget
        // extension may still be running, and WidgetKit refuses a previous version's timelines;
        // the placed widgets keep the previous language's render until they reload.
        let versionChanged = WhatsNewPolicy.lastLaunched != updater.currentVersion
        WidgetRefresher.endPreviousExtension(versionChanged: versionChanged)
        // On a version's first launch, this also starts the version count's day of grace.
        WhatsNewPolicy.markSeen(updater.currentVersion)
        updater.showWindow = { WindowOpener.show(WindowID.update) }
        updater.startAutomaticChecks()
    }

    // Every window and the menu bar panel get `.motionPolicy()` here, outside their root view, so
    // the root view's own `@Environment(\.motion)` sees the window's policy too. The main and
    // compact windows also follow the window style (`.windowLook()`), inside the motion policy and
    // inside the window's registrations (live refresh, the Dock icon policy): a style change
    // rebuilds the content below it, and a rebuilt registration could end up dropped or bring the
    // app forward. The main window applies it in `MainView`, whose page decides its refresh.
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
                .windowLook()
                .liveRefresh(monitor, every: .seconds(2), client: "compact")
                .trackedWindow(WindowID.compact)
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
        // Removing the item may keep its label alive: withdraw the label's polling here too.
        .onChange(of: showInMenuBar) {
            if !showInMenuBar { monitor.setLiveRefreshInterval(nil, for: "menuBar") }
        }

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
            WhatsNewView(previous: previousVersion)
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

final class AppDelegate: NSObject, nonisolated NSApplicationDelegate {
    private var defaultsObserver: (any NSObjectProtocol)?

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
            do {
                try await AppHistory.store.flush()
            } catch {
                HistoryRecorder.logWriteFailure("the day's summaries before quitting", error)
            }
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

    // MARK: Clicks on widgets

    // The delegate takes both routes, never a scene modifier: BatteryPulse usually has no window
    // when a click arrives, often isn't even running, and the app never imports App Intents.

    /// A click on a widget that sets a `widgetURL`: WidgetKit hands BatteryPulse its
    /// `batterypulse://page/…` URL with no scheme registered, so no web page's link finds
    /// BatteryPulse by it. Whatever sends one, a URL that names no page is ignored, and a link
    /// only ever shows a page.
    func application(_ application: NSApplication, open urls: [URL]) {
        openWidgetPage(urls.compactMap(WidgetRoute.init(url:)).last, arrivedBy: "url")
    }

    /// A click that misses the `widgetURL`: an activity whose type is the clicked widget's intent
    /// type name. It carries no configuration BatteryPulse reads, so it opens the kind's own
    /// page; any other activity isn't a widget's.
    func application(
        _ application: NSApplication, continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        let route = WidgetRoute(activityType: userActivity.activityType)
        openWidgetPage(route, arrivedBy: "activity")
        return route != nil
    }

    /// Opens the main window at the route's page. The log says how the click arrived and the
    /// page's case name; a device page's key only hashed, and never the URL or the activity.
    private func openWidgetPage(_ route: WidgetRoute?, arrivedBy: StaticString) {
        let via = arrivedBy.description
        guard let route else {
            Diagnostics.widget.notice("No page for an open by \(via, privacy: .public): ignored")
            return
        }
        let page = SidebarItem(page: route.page)
        let name = page.signpostName.description
        if case .device(let key) = route.page {
            Diagnostics.widget.notice(
                "Widget click by \(via, privacy: .public) opens \(name, privacy: .public) \(key.rawValue, privacy: .private(mask: .hash))"
            )
        } else {
            Diagnostics.widget.notice("Widget click by \(via, privacy: .public) opens \(name, privacy: .public)")
        }
        WindowOpener.showMainWindow(page: page)
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

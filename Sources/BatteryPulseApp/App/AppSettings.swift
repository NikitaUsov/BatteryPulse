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
    static let menuBarShowsIconKey = "menuBarShowsIcon"
    static let menuBarShowsChargeKey = "menuBarShowsCharge"
    static let menuBarShowsPowerKey = "menuBarShowsPower"
    static let menuBarShowsTemperatureKey = "menuBarShowsTemperature"
    static let menuBarIconStyleKey = "menuBarIconStyle"
    /// The menu bar's single content choice and its icon choice before 0.4; ``migrate()`` turns
    /// them into the toggles above.
    static let legacyMenuBarStyleKey = "menuBarStyle"
    static let legacyMenuBarIconKey = "menuBarIcon"
    static let showDeveloperKey = "showDeveloperSection"
    /// The Developer option that drew the cards in Liquid Glass in 0.5; the window style replaced
    /// it in 0.6, and ``migrate()`` deletes it.
    static let legacyGlassCardsKey = "glassCards"
    static let showWelcomeAtLaunchKey = "showWelcomeAtLaunch"
    static let hasSeenWelcomeKey = "hasSeenWelcome"
    /// The on/off switch for update checks before 0.4; ``updateFrequencyKey`` replaced it.
    static let legacyCheckForUpdatesKey = "checkForUpdates"
    static let updateFrequencyKey = "updateFrequency"
    static let lastUpdateCheckKey = "lastUpdateCheck"
    static let skippedVersionKey = "skippedVersion"
    /// Where an in-app update put the previous version, to delete at the next launch.
    static let updateLeftoverKey = "updateLeftover"
    static let lastSeenVersionKey = "lastSeenVersion"
    /// The anonymous version count (Settings → General): on when missing, and only its toggle
    /// writes it, so a later release can change the default for everyone who never chose.
    static let anonymousVersionCountKey = "anonymousVersionCount"
    /// The last version the count is done with, as `x.y.z`: counted, or without a counter on its
    /// release (``VersionCounterPolicy/marksCounted(_:)``).
    static let lastCountedVersionKey = "lastCountedVersion"
    /// When this version first ran on this Mac, written when ``lastSeenVersionKey`` changes. The
    /// count waits a day after it, so its switch comes before the first count.
    static let versionFirstLaunchKey = "versionFirstLaunch"
    static let recordHistoryKey = "recordHistory"
    static let prefersCompactWindowKey = "prefersCompactWindow"
    /// How the main and compact windows look (Settings → General): a `WindowLook` raw value,
    /// Standard when missing or unknown.
    static let windowLookKey = "windowLook"
    /// Settings → Advanced → Beta window styles: Translucent and Clear appear in the window style
    /// picker. Off by default; ``migrate()`` turns it on for a beta style chosen in 0.6.0.
    static let betaWindowStylesKey = "betaWindowStyles"
    static let alertChargeLimitKey = "alertChargeLimit"
    static let alertLowBatteryKey = "alertLowBattery"
    static let alertServiceKey = "alertService"
    static let alertHeatKey = "alertHeat"
    static let alertStateKey = "alertState"
    /// The accessory low-battery threshold in percent; 0 is off.
    static let alertAccessoryLowKey = "alertAccessoryLow"
    /// ``AccessoryAlertState`` as JSON, stored only while that alert is on and has fired.
    static let accessoryAlertStateKey = "accessoryAlertState"
    /// Read iPhone and iPad batteries (Settings → General). Off by default: on, the app loads
    /// Apple's private MobileDevice framework once an iPhone or iPad is plugged in.
    static let readDevicesKey = "readDevices"

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
        let accessoryLow = defaults.integer(forKey: alertAccessoryLowKey)
        return AlertSettings(
            chargeLimit: chargeLimit > 0 ? chargeLimit : nil,
            lowBattery: lowBattery > 0 ? lowBattery : nil,
            serviceRecommended: defaults.bool(forKey: alertServiceKey),
            highTemperature: defaults.bool(forKey: alertHeatKey),
            accessoryLowBattery: accessoryLow > 0 ? accessoryLow : nil
        )
    }

    /// Which window Open BatteryPulse, the Dock icon and a windowed launch show.
    static var prefersCompactWindow: Bool {
        UserDefaults.standard.bool(forKey: prefersCompactWindowKey)
    }

    static var recordsHistory: Bool {
        UserDefaults.standard.object(forKey: recordHistoryKey) as? Bool ?? true
    }

    static var readsDevices: Bool {
        UserDefaults.standard.bool(forKey: readDevicesKey)
    }

    /// The anonymous version count: on unless the user turned it off.
    static var countsVersion: Bool {
        VersionCounterPolicy.isEnabled(stored: UserDefaults.standard.object(forKey: anonymousVersionCountKey) as? Bool)
    }

    /// Daily by default; Settings → General shows the choice.
    static var updateFrequency: UpdateFrequency {
        let defaults = UserDefaults.standard
        return .stored(
            defaults.string(forKey: updateFrequencyKey),
            legacyEnabled: defaults.object(forKey: legacyCheckForUpdatesKey) as? Bool)
    }

    /// Settings renamed since an earlier version keep the user's choice; retired ones are deleted.
    static func migrate() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: updateFrequencyKey) == nil,
            defaults.object(forKey: legacyCheckForUpdatesKey) != nil
        {
            defaults.set(updateFrequency.rawValue, forKey: updateFrequencyKey)
            defaults.removeObject(forKey: legacyCheckForUpdatesKey)
        }
        let menuBarKeys = [
            menuBarShowsIconKey, menuBarShowsChargeKey, menuBarShowsPowerKey, menuBarShowsTemperatureKey,
        ]
        if menuBarKeys.allSatisfy({ defaults.object(forKey: $0) == nil }),
            let content = MenuBarContent.migrated(
                legacyStyle: defaults.string(forKey: legacyMenuBarStyleKey),
                legacyIcon: defaults.string(forKey: legacyMenuBarIconKey))
        {
            defaults.set(content.showsIcon, forKey: menuBarShowsIconKey)
            defaults.set(content.showsCharge, forKey: menuBarShowsChargeKey)
            defaults.set(content.showsPower, forKey: menuBarShowsPowerKey)
            defaults.set(content.showsTemperature, forKey: menuBarShowsTemperatureKey)
        }
        defaults.removeObject(forKey: legacyMenuBarStyleKey)
        defaults.removeObject(forKey: legacyMenuBarIconKey)
        // Not mapped to a window style: it was an experiment with opaque windows, and turning it
        // into a see-through window would choose for the user.
        defaults.removeObject(forKey: legacyGlassCardsKey)
        // Translucent and Clear became beta styles in 0.6.1; a window that used one keeps it.
        if defaults.object(forKey: betaWindowStylesKey) == nil,
            WindowLook.betaStylesStartOn(storedLook: defaults.string(forKey: windowLookKey))
        {
            defaults.set(true, forKey: betaWindowStylesKey)
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
    /// The version that ran before this launch, as What's New sees it: the recorded one, or 0.2
    /// after an earlier welcome window; `nil` on a fresh install. Read before ``markSeen(_:)``.
    static var previousVersion: AppVersion? {
        lastLaunched
            ?? (UserDefaults.standard.bool(forKey: AppSettings.hasSeenWelcomeKey) ? AppVersion(parts: [0, 2]) : nil)
    }

    static func showsAtLaunch(current: AppVersion) -> Bool {
        UpdatePolicy.showsWhatsNew(lastSeen: previousVersion, current: current, features: WhatsNew.version)
    }

    /// The version that ran last, before this launch records itself; `nil` on a fresh install.
    static var lastLaunched: AppVersion? {
        UserDefaults.standard.string(forKey: AppSettings.lastSeenVersionKey).flatMap(AppVersion.init)
    }

    /// Records `version` as the one that ran last and, when it differs from the one before, when
    /// it first ran: the version count's day of grace starts then. Unversioned builds (CI
    /// artifacts share the bundle ID) don't count, or the next real release would show What's New
    /// twice, and running one would restart the installed version's grace.
    static func markSeen(_ version: AppVersion) {
        guard version != UpdateInstallPolicy.unversioned else { return }
        let defaults = UserDefaults.standard
        if lastLaunched != version {
            defaults.set(Date(), forKey: AppSettings.versionFirstLaunchKey)
        }
        defaults.set(version.description, forKey: AppSettings.lastSeenVersionKey)
    }
}

enum AppLinks {
    static let project = ReleaseChannel.project
    static let releases = ReleaseLinks.browserURL(for: ReleaseChannel.releasesPage)
    static let license = ReleaseChannel.file("LICENSE")
    static let help = ReleaseChannel.file("docs/USER_GUIDE.md")
    /// System Settings → General → Language & Region, where per-app languages are chosen.
    // swift-format-ignore: NeverForceUnwrap
    static let languageSettings = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!
    /// System Settings → Menu Bar, where the battery item macOS shows is turned off. Since macOS 26
    /// this pane replaces Control Center but keeps its identifier.
    // swift-format-ignore: NeverForceUnwrap
    static let menuBarSettings = URL(
        string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")!
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

/// Opens app windows from places that have no SwiftUI environment (the Dock and its menu, a click
/// on a widget).
enum WindowOpener {
    /// Captured from any view that appears; `OpenWindowAction` works from any scene. A main
    /// window that a click asked for before any view appeared opens once the first one does.
    static var openWindow: OpenWindowAction? {
        didSet {
            guard openWindow != nil, opensMainWindowWhenReady else { return }
            opensMainWindowWhenReady = false
            show(WindowID.main)
        }
    }

    /// The page a click on a widget asked for, until a main window shows it.
    static let pageRequest = MainPageRequest()

    /// A click that launches BatteryPulse arrives before any view could hand over ``openWindow``.
    private static var opensMainWindowWhenReady = false

    /// The full or the compact window, whichever the user prefers.
    static func showMainWindow() {
        show(AppSettings.prefersCompactWindow ? WindowID.compact : WindowID.main)
    }

    /// The main window at `page`, for a click on a widget: the main window even when the user
    /// prefers the compact one, which has no pages. The request waits for the main window that
    /// shows it (``MainPageRequest``), and the window for ``openWindow``.
    static func showMainWindow(page: SidebarItem) {
        pageRequest.request(page)
        guard openWindow != nil else {
            opensMainWindowWhenReady = true
            return
        }
        show(WindowID.main)
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

/// The page a click on a widget asked the main window to show. It stays until a main window
/// shows it: the click usually finds BatteryPulse quit or without a main window, and a main window
/// created later applies it as it appears, in place of the page its scene storage restores
/// (`MainView`). Clearing it lets the next click ask for the same page again.
@Observable
final class MainPageRequest {
    private(set) var page: SidebarItem?

    func request(_ page: SidebarItem) {
        self.page = page
    }

    /// The main window showed the page.
    func clear() {
        page = nil
    }
}

/// Registers a window for the Dock icon policy and brings the app forward when it opens.
///
/// `.motionPolicy()` is not applied here but around each root view in `BatteryPulseApp`: root
/// views apply this modifier inside their own body, where it would hide `\.motion` from the root
/// view's own `@Environment`.
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
@Observable
final class LaunchAtLoginModel {
    /// One read, so ``isEnabled`` and ``requiresApproval`` always describe the same moment.
    private(set) var status = LaunchAtLogin.status
    private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled }
    /// macOS registered the login item but wants the user to allow it in System Settings.
    var requiresApproval: Bool { status == .requiresApproval }
    var isAvailable: Bool { LaunchAtLogin.isAvailable }

    func refresh() {
        status = LaunchAtLogin.status
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

    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
#endif

#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI
import os

/// The Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                SettingsPage {
                    GeneralSettings(includesWindowStyle: true)
                    DeviceSettings()
                }
            }
            Tab("Menu Bar", systemImage: "menubar.rectangle") {
                SettingsPage { MenuBarSettings() }
            }
            Tab("Notifications", systemImage: "bell.badge") {
                SettingsPage { NotificationSettings() }
            }
            Tab("Advanced", systemImage: "wrench.and.screwdriver") {
                SettingsPage { AdvancedSettings() }
            }
        }
        .frame(width: 500)
        .trackedWindow(WindowID.settings)
    }
}

private struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Two alternatives in one place, such as a note that depends on a setting: switching crossfades
/// between them. Both keep their space, so the height never changes and the windows that size to
/// their content (Settings, Welcome) don't jump. VoiceOver reads only the one shown.
struct Crossfade<First: View, Second: View>: View {
    private let showsFirst: Bool
    private let first: First
    private let second: Second
    @Environment(\.motion) private var motion

    init(
        showsFirst: Bool, @ViewBuilder _ first: () -> First, @ViewBuilder otherwise second: () -> Second
    ) {
        self.showsFirst = showsFirst
        self.first = first()
        self.second = second()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            first
                .opacity(showsFirst ? 1 : 0)
                .accessibilityHidden(!showsFirst)
            second
                .opacity(showsFirst ? 0 : 1)
                .accessibilityHidden(showsFirst)
        }
        // Only opacity changes, so it fades under Reduce Motion too.
        .animation(motion.crossfade, value: showsFirst)
    }
}

/// Where the app appears, startup and language. Also shown in the welcome window, without the
/// window style.
struct GeneralSettings: View {
    /// Settings shows the window style after the window to open; the welcome window doesn't.
    var includesWindowStyle = false
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    @AppStorage(AppSettings.showDockIconKey) private var showDockIcon = false
    @AppStorage(AppSettings.showWelcomeAtLaunchKey) private var showWelcomeAtLaunch = false
    @AppStorage(AppSettings.updateFrequencyKey) private var updateFrequency = UpdateFrequency.daily
    @AppStorage(AppSettings.prefersCompactWindowKey) private var prefersCompactWindow = false
    @Environment(LaunchAtLoginModel.self) private var launchAtLogin
    @Environment(UpdateChecker.self) private var updater

    var body: some View {
        Section {
            Toggle("Show in menu bar", isOn: $showInMenuBar)
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Show Dock icon", isOn: dockIconBinding)
                    .disabled(!showInMenuBar)
                // Separate Text views: a ternary of literals would be a plain String and skip
                // localization.
                Crossfade(showsFirst: showInMenuBar) {
                    Text("Without it, the Dock icon still appears while a BatteryPulse window is open.")
                } otherwise: {
                    Text("BatteryPulse always shows a Dock icon when it isn't in the menu bar.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }

        Section {
            VStack(alignment: .leading, spacing: 4) {
                // A plain Binding, not .onChange: a refresh must never (un)register as a side effect.
                Toggle(
                    "Open at login",
                    isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.set($0) })
                )
                .disabled(!launchAtLogin.isAvailable)
                if !launchAtLogin.isAvailable {
                    Text("Available in the installed app. Build it with scripts/build-app.sh.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if launchAtLogin.requiresApproval {
                    HStack {
                        Text("Allow BatteryPulse in Login Items to finish.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Open Login Items…") { launchAtLogin.openLoginItemsSettings() }
                            .controlSize(.small)
                    }
                } else if let error = launchAtLogin.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Picker("Window to open", selection: $prefersCompactWindow) {
                Text("Full window").tag(false)
                Text("Compact window").tag(true)
            }
            Toggle("Show welcome window at startup", isOn: $showWelcomeAtLaunch)
        }
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }

        if includesWindowStyle {
            WindowLookSettings()
        }

        Section {
            Picker("Check for updates", selection: $updateFrequency) {
                Text("Daily").tag(UpdateFrequency.daily)
                Text("Weekly").tag(UpdateFrequency.weekly)
                Text("Monthly").tag(UpdateFrequency.monthly)
                Text("Never").tag(UpdateFrequency.never)
            }
            LabeledContent {
                Button("Check Now") { updater.checkNow() }
            } label: {
                if let lastCheck = updater.lastCheck {
                    Text("Last checked \(lastCheck.formatted(.relative(presentation: .named)))")
                } else {
                    Text("Not checked yet")
                }
            }
        } footer: {
            Text(
                "To check, BatteryPulse asks GitHub whether a newer version exists. GitHub sees your IP address, the app's version and your language, as with any web request. Check Now works with any choice."
            )
        }

        Section {
            LabeledContent("Language") {
                Button("Change in System Settings…") {
                    NSWorkspace.shared.open(AppLinks.languageSettings)
                }
            }
        } footer: {
            Text("Choose BatteryPulse under Applications in Language & Region.")
        }
    }

    /// Hiding both the menu bar item and the Dock icon would leave no way into the app.
    private var dockIconBinding: Binding<Bool> {
        Binding(get: { showDockIcon || !showInMenuBar }, set: { showDockIcon = $0 })
    }
}

/// iPhones and iPads: the opt-in, last in Settings → General. Not in the welcome window: the
/// setting loads a private framework, so it waits until the user looks for it.
struct DeviceSettings: View {
    @AppStorage(AppSettings.readDevicesKey) private var readsDevices = false

    var body: some View {
        Section {
            // A plain Binding: `setReading` is the only way the setting changes.
            Toggle(
                "Read iPhone and iPad batteries",
                isOn: Binding(get: { readsDevices }, set: { AppDevices.setReading($0) }))
        } header: {
            Text("iPhone and iPad")
        } footer: {
            Text(
                "Reads a device that trusts this Mac when it's connected by cable, then every 5 minutes while battery history is recorded. Over Wi-Fi, only when you click Refresh or Check Again. BatteryPulse never pairs with a device, and nothing leaves this Mac."
            )
        }
    }
}

/// What the menu bar item shows and how its battery icon looks.
struct MenuBarSettings: View {
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    // The defaults of MenuBarContent: the icon and the charge.
    @AppStorage(AppSettings.menuBarShowsIconKey) private var showsIcon = true
    @AppStorage(AppSettings.menuBarShowsChargeKey) private var showsCharge = true
    @AppStorage(AppSettings.menuBarShowsPowerKey) private var showsPower = false
    @AppStorage(AppSettings.menuBarShowsTemperatureKey) private var showsTemperature = false
    @AppStorage(AppSettings.menuBarIconStyleKey) private var iconStyle = MenuBarIconStyle.default

    private var content: MenuBarContent {
        MenuBarContent(
            showsIcon: showsIcon, showsCharge: showsCharge, showsPower: showsPower, showsTemperature: showsTemperature)
    }

    var body: some View {
        Section {
            // The last item that is on can't be turned off: the status item would be empty.
            Toggle("Battery icon", isOn: $showsIcon)
                .disabled(content.isOnlyItem(.icon))
            Toggle("Percentage", isOn: $showsCharge)
                .disabled(content.isOnlyItem(.charge))
            Toggle("Battery power", isOn: $showsPower)
                .disabled(content.isOnlyItem(.power))
            Toggle("Temperature", isOn: $showsTemperature)
                .disabled(content.isOnlyItem(.temperature))
        } header: {
            Text("Show")
        } footer: {
            if showInMenuBar {
                Text("The menu bar always shows at least one item.")
            } else {
                Text("BatteryPulse isn't in the menu bar. Turn it on in General.")
            }
        }
        .disabled(!showInMenuBar)

        Section {
            PreviewTilePicker(selection: $iconStyle, values: MenuBarIconStyle.allCases, title: \.title) { style in
                MenuBarIconPreview(style: style, magnification: PreviewTile.iconMagnification)
            }
        } header: {
            Text("Icon Style")
        }
        .disabled(!showInMenuBar || !content.items.contains(.icon))

        Section {
            LabeledContent("macOS battery item") {
                Button("Open Menu Bar Settings…") {
                    NSWorkspace.shared.open(AppLinks.menuBarSettings)
                }
            }
        } footer: {
            Text(
                "BatteryPulse can't hide the battery item macOS shows. To use BatteryPulse in its place, turn off Battery in System Settings → Menu Bar."
            )
        }
    }
}

/// Choices side by side as tiles, each a preview with its name below, like the Icon & widget
/// style tiles of macOS: the menu bar's icon styles and the window styles. Every tile gives its
/// preview the same frame, so the tiles match.
///
/// The selected tile is marked by an accent outline only, as System Settings marks its appearance
/// thumbnails: every tile keeps the same standard fill, so a preview looks the same selected or
/// not, and nothing is glass. The outline crossfades to the new tile. The choice itself is set
/// without animation: only the tiles animate, never what the choice changes.
struct PreviewTilePicker<Value: RawRepresentable & Hashable, Preview: View>: View where Value.RawValue == String {
    @Binding var selection: Value
    let values: [Value]
    let title: (Value) -> LocalizedStringKey
    @ViewBuilder let preview: (Value) -> Preview
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motion) private var motion
    @Environment(\.accessibilityShowBorders) private var showsBorders

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(values, id: \.self) { value in
                tile(value)
            }
        }
        // The outline is a colour change, so it crossfades; nothing moves.
        .animation(motion.crossfade, value: selection)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func tile(_ value: Value) -> some View {
        let isSelected = value == selection
        let shape = RoundedRectangle(cornerRadius: PreviewTile.cornerRadius)
        return Button {
            selection = value
        } label: {
            VStack(spacing: 8) {
                preview(value)
                    .frame(height: PreviewTile.previewHeight)
                Text(title(value))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(.fill.quaternary, in: shape)
            .overlay {
                // Show Borders: every tile gets a visible edge, not only the selected one.
                if showsBorders {
                    shape.strokeBorder(.separator, lineWidth: 1)
                }
            }
            .overlay {
                shape.strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title(value)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The tiles' measurements; a generic type can't store them.
private enum PreviewTile {
    static let cornerRadius: CGFloat = 8
    /// Every preview's height: a window style's drawing (``WindowLookPreview``).
    static let previewHeight: CGFloat = WindowLookPreview.size.height
    /// The menu bar icons are drawn larger in a tile this size; each still takes the same frame
    /// (``BatteryIconLayout/previewSize``).
    static let iconMagnification: CGFloat = 2.5
}

/// Which battery notifications to post.
struct NotificationSettings: View {
    @AppStorage(AppSettings.alertChargeLimitKey) private var chargeLimit = 0
    @AppStorage(AppSettings.alertLowBatteryKey) private var lowBattery = 0
    @AppStorage(AppSettings.alertAccessoryLowKey) private var accessoryLow = 0
    @AppStorage(AppSettings.alertServiceKey) private var service = false
    @AppStorage(AppSettings.alertHeatKey) private var heat = false
    @State private var isDenied = false
    private let formatter = BatteryFormatter.app

    var body: some View {
        Section {
            Picker("When charged to", selection: $chargeLimit) {
                Text("Off").tag(0)
                ForEach([80, 85, 90, 95, 100], id: \.self) { Text(formatter.percent(Double($0))).tag($0) }
            }
            // On a row that is always there, not on a Section or the rows that come and go with
            // isDenied, so each runs once and the task doesn't restart.
            .task { isDenied = await BatteryNotifier.isDenied() }
            // Notifications may have been turned on or off in System Settings meanwhile.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { isDenied = await BatteryNotifier.isDenied() }
            }
            .onChange(of: [chargeLimit, lowBattery, accessoryLow, service ? 1 : 0, heat ? 1 : 0]) { _, _ in
                // Ask for permission the first time something is turned on.
                guard AppSettings.alerts.isAnyEnabled else { return }
                Task {
                    _ = await BatteryNotifier.requestAuthorization()
                    isDenied = await BatteryNotifier.isDenied()
                }
            }
            Picker("When the battery falls to", selection: $lowBattery) {
                Text("Off").tag(0)
                ForEach([10, 20, 30], id: \.self) { Text(formatter.percent(Double($0))).tag($0) }
            }
            // Bluetooth keyboards, mice, trackpads and headphones; once per discharge each.
            Picker("When an accessory falls to", selection: $accessoryLow) {
                Text("Off").tag(0)
                ForEach([10, 20, 30], id: \.self) { Text(formatter.percent(Double($0))).tag($0) }
            }
            Toggle("When battery service is recommended", isOn: $service)
            Toggle("When the Mac gets hot", isOn: $heat)
        } header: {
            Text("Notify Me")
        } footer: {
            Text(
                "Unplugging at around 80 percent most of the time slows battery aging. BatteryPulse must be running to notify you."
            )
        }

        Section {
            if !BatteryNotifier.isAvailable {
                Text("Notifications work in the packaged app, not under swift run.")
                    .foregroundStyle(.secondary)
            } else if isDenied {
                Text("Notifications are turned off for BatteryPulse in System Settings.")
                    .foregroundStyle(.secondary)
                Button("Open Notification Settings") { NSWorkspace.shared.open(AppLinks.notificationSettings) }
            } else {
                LabeledContent("Preview") {
                    Button("Send Test Notification") {
                        Task {
                            if await BatteryNotifier.requestAuthorization() { BatteryNotifier.sendTest() }
                            isDenied = await BatteryNotifier.isDenied()
                        }
                    }
                }
            }
        }
    }
}

/// History, the Developer section and help.
struct AdvancedSettings: View {
    @AppStorage(AppSettings.showDeveloperKey) private var showsDeveloper = false
    @AppStorage(AppSettings.recordHistoryKey) private var recordsHistory = true
    @AppStorage(AppSettings.readDevicesKey) private var readsDevices = false
    @Environment(IDeviceMonitor.self) private var devices
    @State private var confirmsClearing = false

    var body: some View {
        Section {
            Toggle("Record battery history", isOn: $recordsHistory)
                // The 5-minute reads of iPhones and iPads start or stop with it.
                .onChange(of: recordsHistory) { devices.historySettingChanged() }
            LabeledContent("Recorded history") {
                Button("Clear History…", role: .destructive) { confirmsClearing = true }
            }
        } header: {
            Text("History")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "About once a minute while BatteryPulse runs, for the last 10 days, plus the battery's capacity and cycles once a day. It stays on this Mac."
                )
                if readsDevices {
                    Text("iPhones and iPads connected by cable are recorded too, every 5 minutes.")
                }
            }
        }
        .confirmationDialog("Clear the battery history?", isPresented: $confirmsClearing) {
            Button("Clear History", role: .destructive) {
                // Every device's history too; the remembered devices stay.
                Task {
                    do {
                        try await AppHistory.store.clear()
                    } catch {
                        // Some or all of the history stays on disk. The error's domain and code
                        // are public, its description, which can name a path, is not.
                        let error = error as NSError
                        Diagnostics.history.error(
                            "Clearing the history failed (\(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
                        )
                    }
                    await devices.clearHistory()
                }
            }
        } message: {
            Text("The charts start over. This can't be undone.")
        }

        Section {
            Toggle("Show Developer section", isOn: $showsDeveloper)
        } footer: {
            Text(
                "Adds Raw Data (every value macOS reports, decoded and explained) and Demo Mode to the main window."
            )
        }

        Section {
            LabeledContent("Help") {
                Button("Open User Guide") {
                    NSWorkspace.shared.open(AppLinks.help)
                }
            }
            LabeledContent("Version") {
                HStack {
                    if let version = AppInfo.version {
                        Text(verbatim: version)
                            .textSelection(.enabled)
                    }
                    Button("About BatteryPulse") { WindowOpener.show(WindowID.about) }
                }
            }
        }
    }
}
#endif

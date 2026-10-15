#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

/// The Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                SettingsPage { GeneralSettings() }
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

/// Where the app appears, startup and language. Also shown in the welcome window.
struct GeneralSettings: View {
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
                Group {
                    // Separate Text views: a ternary of literals would be a plain String and skip
                    // localization.
                    if showInMenuBar {
                        Text("Without it, the Dock icon still appears while a BatteryPulse window is open.")
                    } else {
                        Text("BatteryPulse always shows a Dock icon when it isn't in the menu bar.")
                    }
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
            MenuBarIconStylePicker(selection: $iconStyle)
        } header: {
            Text("Icon Style")
        }
        .disabled(!showInMenuBar || !content.items.contains(.icon))

        Section {
            LabeledContent("macOS battery item") {
                Button("Open Control Center Settings…") {
                    NSWorkspace.shared.open(AppLinks.controlCenterSettings)
                }
            }
        } footer: {
            Text(
                "BatteryPulse can't hide the battery item macOS shows. To use BatteryPulse in its place, turn off Show in Menu Bar for Battery in Control Center settings."
            )
        }
    }
}

/// The icon styles side by side, each drawn as it looks in the menu bar.
private struct MenuBarIconStylePicker: View {
    @Binding var selection: MenuBarIconStyle
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                let isSelected = style == selection
                Button {
                    selection = style
                } label: {
                    VStack(spacing: 8) {
                        MenuBarIconPreview(style: style)
                            .frame(height: 24)
                        Text(style.title)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                    .background(.fill.quaternary, in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(style.title))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// Which battery notifications to post.
struct NotificationSettings: View {
    @AppStorage(AppSettings.alertChargeLimitKey) private var chargeLimit = 0
    @AppStorage(AppSettings.alertLowBatteryKey) private var lowBattery = 0
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
            Picker("When the battery falls to", selection: $lowBattery) {
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
        .task { isDenied = await BatteryNotifier.isDenied() }
        .onChange(of: [chargeLimit, lowBattery, service ? 1 : 0, heat ? 1 : 0]) { _, _ in
            // Ask for permission the first time something is turned on.
            guard AppSettings.alerts.isAnyEnabled else { return }
            Task {
                _ = await BatteryNotifier.requestAuthorization()
                isDenied = await BatteryNotifier.isDenied()
            }
        }
    }
}

/// History, the Developer section and help.
struct AdvancedSettings: View {
    @AppStorage(AppSettings.showDeveloperKey) private var showsDeveloper = false
    @AppStorage(AppSettings.recordHistoryKey) private var recordsHistory = true
    @State private var confirmsClearing = false

    var body: some View {
        Section {
            Toggle("Record battery history", isOn: $recordsHistory)
            LabeledContent("Recorded history") {
                Button("Clear History…", role: .destructive) { confirmsClearing = true }
            }
        } header: {
            Text("History")
        } footer: {
            Text(
                "About once a minute while BatteryPulse runs, for the last 10 days, plus the battery's capacity and cycles once a day. It stays on this Mac."
            )
        }
        .confirmationDialog("Clear the battery history?", isPresented: $confirmsClearing) {
            Button("Clear History", role: .destructive) {
                Task { try? await AppHistory.store.clear() }
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

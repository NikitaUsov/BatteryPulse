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
    @Environment(LaunchAtLoginModel.self) private var launchAtLogin

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
                }
            }
            Toggle("Show welcome window at startup", isOn: $showWelcomeAtLaunch)
        }
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
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

/// What the menu bar item shows.
struct MenuBarSettings: View {
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    @AppStorage(AppSettings.menuBarStyleKey) private var menuBarStyle: MenuBarStyle = .percent
    @AppStorage(AppSettings.menuBarIconKey) private var menuBarIcon: MenuBarIconStyle = .standard

    var body: some View {
        Section {
            Picker("Show", selection: $menuBarStyle) {
                ForEach(MenuBarStyle.allCases, id: \.self) { style in
                    Text(style.title).tag(style)
                }
            }
            Picker("Battery icon", selection: $menuBarIcon) {
                ForEach(MenuBarIconStyle.allCases, id: \.self) { icon in
                    Text(icon.title).tag(icon)
                }
            }
        } footer: {
            if showInMenuBar {
                Text("The icon can only be hidden when the menu bar also shows text.")
            } else {
                Text("BatteryPulse isn't in the menu bar. Turn it on in General.")
            }
        }
        .disabled(!showInMenuBar)
    }
}

/// Extra sections for the curious.
struct AdvancedSettings: View {
    @AppStorage(AppSettings.showDeveloperKey) private var showsDeveloper = false

    var body: some View {
        Section {
            Toggle("Show Developer section", isOn: $showsDeveloper)
        } footer: {
            Text("Adds raw IORegistry data, charger reason codes and capture export to the main window.")
        }

        Section {
            LabeledContent("Help") {
                Button("Open User Guide") {
                    NSWorkspace.shared.open(AppLinks.help)
                }
            }
        }
    }
}
#endif

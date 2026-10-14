#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

/// The app's Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        Form {
            GeneralSettings()
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Settings shared by the Settings window and the welcome window.
struct GeneralSettings: View {
    @AppStorage(AppSettings.menuBarStyleKey) private var menuBarStyle: MenuBarStyle = .percent
    @AppStorage(AppSettings.menuBarIconKey) private var menuBarIcon: MenuBarIconStyle = .standard
    @AppStorage(AppSettings.showWelcomeAtLaunchKey) private var showWelcomeAtLaunch = false
    @Environment(LaunchAtLoginModel.self) private var launchAtLogin

    var body: some View {
        Picker("Menu bar shows:", selection: $menuBarStyle) {
            ForEach(MenuBarStyle.allCases, id: \.self) { style in
                Text(style.title).tag(style)
            }
        }

        Picker("Battery icon:", selection: $menuBarIcon) {
            ForEach(MenuBarIconStyle.allCases, id: \.self) { icon in
                Text(icon.title).tag(icon)
            }
        }
        .help("Hidden only applies when the menu bar also shows text.")

        VStack(alignment: .leading, spacing: 4) {
            // A plain Binding, not .onChange: a refresh must never (un)register as a side effect.
            Toggle(
                "Launch at login",
                isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.set($0) })
            )
            .disabled(!launchAtLogin.isAvailable)
            if !launchAtLogin.isAvailable {
                // `swift run` starts a bare executable, which macOS can't register as a login item.
                Text("Available in the installed app. Build it with scripts/build-app.sh.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        Toggle("Show the welcome window when BatteryPulse starts", isOn: $showWelcomeAtLaunch)
            .onAppear { launchAtLogin.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                launchAtLogin.refresh()
            }
    }
}
#endif

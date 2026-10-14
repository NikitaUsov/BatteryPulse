#if os(macOS)
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
    @AppStorage(AppSettings.showWelcomeAtLaunchKey) private var showWelcomeAtLaunch = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Picker("Menu bar shows:", selection: $menuBarStyle) {
            ForEach(MenuBarStyle.allCases, id: \.self) { style in
                Text(style.title).tag(style)
            }
        }

        Toggle("Launch at login", isOn: $launchAtLogin)
            .disabled(!LaunchAtLogin.isAvailable)
            .help(LaunchAtLogin.isAvailable ? "" : "Available in the packaged app")
            .onChange(of: launchAtLogin) { _, enabled in
                do {
                    try LaunchAtLogin.set(enabled)
                } catch {
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            }

        Toggle("Show the welcome window when BatteryPulse starts", isOn: $showWelcomeAtLaunch)
    }
}
#endif

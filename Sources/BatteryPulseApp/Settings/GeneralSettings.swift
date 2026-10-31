#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

/// Where the app appears, startup, updates, the version count and language. Also shown in the
/// welcome window, without the window style, so a fresh install sees the count's setting first.
struct GeneralSettings: View {
    /// Settings shows the window style after the window to open; the welcome window doesn't.
    var includesWindowStyle = false
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    @AppStorage(AppSettings.showDockIconKey) private var showDockIcon = false
    @AppStorage(AppSettings.showWelcomeAtLaunchKey) private var showWelcomeAtLaunch = false
    @AppStorage(AppSettings.updateFrequencyKey) private var updateFrequency = UpdateFrequency.daily
    @AppStorage(AppSettings.prefersCompactWindowKey) private var prefersCompactWindow = false
    /// Read as on while missing; only the toggle writes it.
    @AppStorage(AppSettings.anonymousVersionCountKey) private var countsVersion = VersionCounterPolicy.isOnByDefault
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
            // On the row they refresh, not on the Section, which may give each of its rows a copy.
            .onAppear { launchAtLogin.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                launchAtLogin.refresh()
            }
            Picker("Window to open", selection: $prefersCompactWindow) {
                Text("Full window").tag(false)
                Text("Compact window").tag(true)
            }
            Toggle("Show welcome window at startup", isOn: $showWelcomeAtLaunch)
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

        // The version count rides on the automatic checks: under Never it can't run, and the
        // toggle keeps its value until they are on again.
        Section {
            Toggle("Include this Mac in the anonymous version count", isOn: $countsVersion)
                .disabled(updateFrequency == .never)
        } footer: {
            Text(
                "Once per version, at least a day after you start using it, an automatic update check also downloads a small file from that version's release on GitHub. Its public download count shows how many Macs use each version. Nothing else is sent: no identifier and nothing about this Mac, its battery or your settings. Nothing is counted when Check for updates is Never."
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
#endif

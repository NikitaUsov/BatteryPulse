#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI
import os

/// History, the Developer section, the beta window styles and help.
struct AdvancedSettings: View {
    @AppStorage(AppSettings.showDeveloperKey) private var showsDeveloper = false
    @AppStorage(AppSettings.betaWindowStylesKey) private var betaWindowStyles = false
    @AppStorage(AppSettings.windowLookKey) private var windowLook = WindowLook.standard
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
                    // On the button that asks, not on the Section, which may give each of its
                    // rows a copy.
                    .confirmationDialog("Clear the battery history?", isPresented: $confirmsClearing) {
                        Button("Clear History", role: .destructive, action: clearHistory)
                    } message: {
                        Text("The charts start over. This can't be undone.")
                    }
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

        Section {
            Toggle("Show Developer section", isOn: $showsDeveloper)
        } footer: {
            Text(
                "Adds Raw Data (every value macOS reports, decoded and explained) and Demo Mode to the main window."
            )
        }

        Section {
            Toggle("Beta window styles", isOn: $betaWindowStyles)
                // Off, a beta style goes back to Standard, so the picker shows what the windows draw.
                .onChange(of: betaWindowStyles) {
                    windowLook = windowLook.available(betaStyles: betaWindowStyles)
                }
        } footer: {
            Text(
                "Adds Translucent and Clear to Window Style in General. They are still in beta: harder to read, and they use more energy."
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

    /// Every device's history too; the remembered devices stay.
    private func clearHistory() {
        Task {
            do {
                try await AppHistory.store.clear()
            } catch {
                // Some or all of the history stays on disk. The error's domain and code are
                // public, its description, which can name a path, is not.
                let error = error as NSError
                Diagnostics.history.error(
                    "Clearing the history failed (\(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
                )
            }
            await devices.clearHistory()
        }
    }
}
#endif

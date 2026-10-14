#if os(macOS)
import AppKit
import SwiftUI

/// Shown on first launch (and at every launch if the user keeps it enabled).
struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 24) {
                AppIconView()
                    .frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to BatteryPulse")
                        .font(.title2.weight(.semibold))
                    Group {
                        if showInMenuBar {
                            Text(
                                "BatteryPulse is running in your menu bar. Click its icon for a quick look, or open the main window for every detail."
                            )
                        } else {
                            Text(
                                "BatteryPulse runs as a regular app. Open it from the Dock or the Applications folder.")
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            Form {
                GeneralSettings()
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Quit") { NSApp.terminate(nil) }
                Spacer()
                Button("Open BatteryPulse") {
                    dismissWindow(id: WindowID.welcome)
                    WindowOpener.showMainWindow()
                }
                Button("Done") { dismissWindow(id: WindowID.welcome) }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 600)
        .onAppear { UserDefaults.standard.set(true, forKey: AppSettings.hasSeenWelcomeKey) }
        .trackedWindow(WindowID.welcome)
    }
}
#endif

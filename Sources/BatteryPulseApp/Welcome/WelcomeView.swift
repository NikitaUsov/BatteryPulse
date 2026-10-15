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
                // The pulse line draws in once, the first time the window appears after launch.
                AppIconView(drawsIn: true)
                    .frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to BatteryPulse")
                        .font(.title2.weight(.semibold))
                    // Changes with "Show in menu bar" below.
                    Crossfade(showsFirst: showInMenuBar) {
                        Text(
                            "BatteryPulse is running in your menu bar. Click its icon for a quick look, or open the main window for every detail."
                        )
                    } otherwise: {
                        Text("BatteryPulse runs as a regular app. Open it from the Dock or the Applications folder.")
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
                    // Open first, so the app always has a window and keeps its Dock icon.
                    WindowOpener.showMainWindow()
                    dismissWindow(id: WindowID.welcome)
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

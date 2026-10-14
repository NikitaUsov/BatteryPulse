#if os(macOS)
import AppKit
import SwiftUI

/// Shown on first launch (and at every launch if the user keeps it enabled).
struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 24) {
                AppIconView()
                    .frame(width: 128, height: 128)
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        "BatteryPulse is now running. You can find its icon on the right side of your menu bar."
                    )
                    Text(
                        "Click the icon to see charge, power and battery health. Choose Details… there for every reading your Mac reports."
                    )
                    .fontWeight(.semibold)
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
                Button("Close") { dismissWindow(id: WindowID.welcome) }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 600)
        .onAppear {
            UserDefaults.standard.set(true, forKey: AppSettings.hasSeenWelcomeKey)
            NSApp.activate()
        }
    }
}
#endif

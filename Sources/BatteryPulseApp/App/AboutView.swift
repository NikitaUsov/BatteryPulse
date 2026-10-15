#if os(macOS)
import AppKit
import SwiftUI

/// About BatteryPulse: the version and build, what the app is, its links and license.
struct AboutView: View {
    @Environment(UpdateChecker.self) private var updater

    var body: some View {
        VStack(spacing: 14) {
            AppIconView()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text(verbatim: "BatteryPulse")
                    .font(.title.weight(.semibold))
                if let version = AppInfo.version {
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("Development build")
                        .foregroundStyle(.secondary)
                }
            }
            Text("Battery and charging details for your Mac.")
                .multilineTextAlignment(.center)
            VStack(spacing: 6) {
                Link("Project Page", destination: AppLinks.project)
                Link("User Guide", destination: AppLinks.help)
                Link("Release Notes", destination: AppLinks.releases)
            }
            Button("Check for Updates…") { updater.checkNow() }
                .disabled(updater.isUnversioned)
            Link(destination: AppLinks.license) {
                Text("Free software under the GNU General Public License, version 3.")
                    .multilineTextAlignment(.center)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 340)
        .trackedWindow(WindowID.about)
    }
}

/// The app's version as the bundle reports it.
enum AppInfo {
    /// "0.4.0 (12)", or `nil` for a build without a version (CI artifacts, `swift run`).
    static var version: String? {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String, short != "0.0.0" else { return nil }
        guard let build = info?["CFBundleVersion"] as? String, build != short else { return short }
        return "\(short) (\(build))"
    }
}
#endif

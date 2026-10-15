#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

/// The Software Update window: checking, up to date, failed, or a new version with its notes.
struct UpdateView: View {
    @Environment(UpdateChecker.self) private var updater
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.motion) private var motion
    /// Counts failed installs while the window is open; the warning symbol bounces on each.
    @State private var failures = 0

    /// The kinds of status, without their values: a new kind crossfades the window's content.
    private enum StatusKind: Equatable {
        case idle, checking, upToDate, failed, available
    }

    /// The installer's phases, without the download fraction that changes five times a second.
    private enum PhaseKind: Equatable {
        case idle, downloading, verifying, installing, relaunching, failed
    }

    private var statusKind: StatusKind {
        switch updater.status {
        case .idle: .idle
        case .checking: .checking
        case .upToDate: .upToDate
        case .failed, .rateLimited: .failed
        case .available: .available
        }
    }

    private var phaseKind: PhaseKind {
        switch updater.installer.phase {
        case .idle: .idle
        case .downloading: .downloading
        case .verifying: .verifying
        case .installing: .installing
        case .relaunching: .relaunching
        case .failed: .failed
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            AppIconView()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // A new status crossfades. The window sizes to its content, so its height changes at
            // once: the fade is attached to the transition, and nothing else is animated.
            .id(statusKind)
            .transition(AnyTransition.opacity.animation(motion.change))
        }
        .padding(24)
        .frame(width: 540)
        .onChange(of: phaseKind) { _, phase in
            // One bounce of the warning symbol per failure; a one-off extra.
            if phase == .failed, motion.allowsFlourish { failures += 1 }
        }
        .trackedWindow(WindowID.update)
    }

    @ViewBuilder
    private var content: some View {
        let current = updater.currentVersion.description
        switch updater.status {
        case .checking:
            Text("Checking for Updates…")
                .font(.title3.weight(.semibold))
            ProgressView()
                .progressViewStyle(.linear)
        case .idle:
            Text("Software Update")
                .font(.title3.weight(.semibold))
            Text("You have BatteryPulse \(current).")
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Close") { close() }
                Button("Check Now") { updater.checkNow() }
                    .keyboardShortcut(.defaultAction)
            }
        case .upToDate:
            Text("BatteryPulse Is Up to Date")
                .font(.title3.weight(.semibold))
            Text("Version \(current) is the latest.")
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("OK") { close() }
                    .keyboardShortcut(.defaultAction)
            }
        case .failed, .rateLimited:
            Text("Couldn't Check for Updates")
                .font(.title3.weight(.semibold))
            Group {
                if updater.status == .rateLimited {
                    Text("GitHub is limiting requests from your network. Try again later.")
                } else {
                    Text("Check your internet connection and try again.")
                }
            }
            .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Close") { close() }
                Button("Try Again") { updater.checkNow() }
                    .keyboardShortcut(.defaultAction)
            }
        case .available(let release):
            let version = release.version.description
            Text("A New Version of BatteryPulse Is Available")
                .font(.title3.weight(.semibold))
            Text("BatteryPulse \(version) is available; you have \(current).")
                .foregroundStyle(.secondary)
            ScrollView {
                Text(notes(release))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 220)
            .background(.background.secondary, in: .rect(cornerRadius: 10, style: .continuous))
            // A new phase crossfades its label; the download bar inside a phase is never animated,
            // because its fraction changes five times a second.
            installStatus(release)
                .id(phaseKind)
                .transition(AnyTransition.opacity.animation(motion.change))
            installActions(release)
        }
    }

    /// How the update gets installed, the installation's progress, or why it stopped.
    @ViewBuilder
    private func installStatus(_ release: ReleaseInfo) -> some View {
        let installer = updater.installer
        switch installer.phase {
        case .downloading(let fraction):
            ProgressView(value: fraction) {
                Text("Downloading…")
            }
        case .verifying:
            ProgressView {
                Text("Verifying the update…")
            }
            .progressViewStyle(.linear)
        case .installing:
            ProgressView {
                Text("Installing…")
            }
            .progressViewStyle(.linear)
        case .relaunching:
            ProgressView {
                Text("Relaunching…")
            }
            .progressViewStyle(.linear)
        case .failed(let error):
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(error.message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .symbolEffect(.bounce, options: .nonRepeating, value: failures)
                }
                if error.fallsBackToDownload {
                    Text("You can download the update and install it from the DMG instead.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
        case .idle:
            Group {
                if let blocker = installer.blocker(for: release) {
                    if let reason = blocker.reason {
                        Text(reason)
                    }
                    Text(
                        "Open the downloaded DMG and drag BatteryPulse to Applications to replace this copy. macOS asks once in Privacy & Security before the new version opens."
                    )
                } else {
                    Text("BatteryPulse downloads the update, checks its signature, replaces this copy and opens again.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Install and Relaunch when the app can replace itself, otherwise the browser download.
    /// Two rows, so the longer Russian labels fit the window.
    @ViewBuilder
    private func installActions(_ release: ReleaseInfo) -> some View {
        let installer = updater.installer
        if installer.isBusy {
            HStack {
                Spacer()
                Button("Cancel") { installer.cancel() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(!installer.canCancel)
            }
        } else {
            HStack {
                Button("Skip This Version") {
                    updater.skip(release)
                    close()
                }
                Spacer()
                Button("Remind Me Later") {
                    updater.dismiss()
                    close()
                }
            }
            HStack {
                Spacer()
                if installer.phase == .failed(.relaunchFailed) {
                    // The new version is in place; it only has to be opened.
                    Button("Quit BatteryPulse") { NSApp.terminate(nil) }
                        .keyboardShortcut(.defaultAction)
                } else if installer.phase == .idle, installer.blocker(for: release) == nil {
                    Button("Download") { download(release) }
                    Button("Install and Relaunch") { installer.install(release) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    if installer.canRetry {
                        Button("Try Again") { installer.install(release) }
                    }
                    Button("Download") { download(release) }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    /// The DMG in the browser: the fallback whenever the app can't install the update itself.
    private func download(_ release: ReleaseInfo) {
        updater.download(release)
        close()
    }

    private func notes(_ release: ReleaseInfo) -> AttributedString {
        let markdown = ReleaseNotes.inlineMarkdown(release.notes)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        return (try? AttributedString(markdown: markdown, options: options, baseURL: release.pageURL))
            ?? AttributedString(release.notes)
    }

    private func close() {
        dismissWindow(id: WindowID.update)
    }
}

/// Shown once after an update: what this version adds.
struct WhatsNewView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.motion) private var motion
    /// Set when the window appears: the rows enter, one after another, once.
    @State private var hasEntered = false

    var body: some View {
        // Only with one-off extras allowed; otherwise the rows are simply there.
        let entrance = StaggeredEntrance(motion)
        VStack(spacing: 22) {
            AppIconView()
                .frame(width: 88, height: 88)
            Text("What's New in BatteryPulse")
                .font(.title.weight(.semibold))
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(WhatsNew.features.enumerated()), id: \.element.id) { index, feature in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: feature.symbol)
                            .font(.title2)
                            .foregroundStyle(.tint)
                            .frame(width: 34)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.headline)
                            Text(feature.detail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    // Fades in and rises a few points, a moment after the row above; the layout
                    // never changes, so the window keeps its size.
                    .opacity(hasEntered ? 1 : entrance.opacityBeforeEntering)
                    .offset(y: hasEntered ? 0 : entrance.offsetBeforeEntering)
                    .animation(
                        entrance.plays ? motion.change?.delay(entrance.delay(forRow: index)) : nil, value: hasEntered)
                }
            }
            Button("Continue") { dismissWindow(id: WindowID.whatsNew) }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(32)
        .frame(width: 520)
        .onAppear { hasEntered = true }
        .trackedWindow(WindowID.whatsNew)
    }
}

/// The features of this version, for What's New.
@MainActor
enum WhatsNew {
    /// The version these features arrived in; What's New appears once after updating to it or
    /// past it, and not again for later bug-fix releases.
    nonisolated static let version = AppVersion(parts: [0, 4, 0])

    struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    static let features: [Feature] = [
        Feature(
            id: 1, symbol: "menubar.rectangle", title: "Menu bar styles",
            detail:
                "Show any mix of the battery icon, charge, power and temperature, with new icon styles drawn to the exact level. Settings → Menu Bar."
        ),
        Feature(
            id: 2, symbol: "arrow.down.app", title: "Install updates from the app",
            detail:
                "BatteryPulse downloads the next version, checks its signature and opens again. Choose how often to check in Settings → General."
        ),
        Feature(
            id: 3, symbol: "bolt.fill", title: "Charging at once",
            detail: "Charging and the battery's power show a few seconds after you plug in, read live from the battery."
        ),
        Feature(
            id: 4, symbol: "thermometer.medium", title: "Temperature in the menu bar",
            detail: "The battery's temperature in the menu bar and its popover."),
        Feature(
            id: 5, symbol: "info.circle", title: "About BatteryPulse",
            detail: "The version, links and license, from the BatteryPulse menu or the popover."),
        Feature(
            id: 6, symbol: "list.bullet.rectangle", title: "More explanations in Raw Data",
            detail: "The battery pack, its cells and the charger entries now explain their keys."),
    ]
}
#endif

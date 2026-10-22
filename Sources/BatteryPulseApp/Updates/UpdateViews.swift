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
            // A new status fades in. The window sizes to its content, so the old status goes at
            // once and is never laid out beside or above the new one: the window resizes once,
            // to the new content, and nothing else is animated. The ZStack keeps the new status
            // in the old one's place while it is swapped.
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(statusKind)
                .transition(motion.replacement)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            let installer = updater.installer
            // Only while idle: a blocker looks at the file system, and during a download this runs
            // on every progress step.
            let blocker = installer.phase == .idle ? installer.blocker(for: release) : nil
            Text("A New Version of BatteryPulse Is Available")
                .font(.title3.weight(.semibold))
            Text("BatteryPulse \(version) is available; you have \(current).")
                .foregroundStyle(.secondary)
            ReleaseNotesText(notes: release.notes, baseURL: release.pageURL)
            // A new phase fades in where the old one was, which goes at once: the window resizes
            // once per phase and the buttons below move at most once, with it. The download bar
            // inside a phase is never animated, because its fraction changes five times a second.
            ZStack(alignment: .topLeading) {
                installStatus(blocker: blocker)
                    .id(phaseKind)
                    .transition(motion.replacement)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            installActions(release, blocker: blocker)
        }
    }

    /// How the update gets installed, the installation's progress, or why it stopped. `blocker`
    /// is the idle phase's reason why the app can't install the update itself.
    @ViewBuilder
    private func installStatus(blocker: UpdateInstallError?) -> some View {
        switch updater.installer.phase {
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
            warning(error)
        case .idle:
            if let blocker, blocker.fallback == .releasePage {
                warning(blocker)
            } else {
                Group {
                    if let blocker {
                        if let reason = blocker.reason {
                            Text(reason)
                        }
                        Text(
                            "Open the downloaded DMG and drag BatteryPulse to Applications to replace this copy. macOS asks once in Privacy & Security before the new version opens."
                        )
                    } else {
                        Text(
                            "BatteryPulse downloads the update, checks its signature, replaces this copy and opens again."
                        )
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// A warning: why the update wasn't installed, or can't be, and the way forward that
    /// ``UpdateFallback`` allows.
    private func warning(_ error: UpdateInstallError) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(error.message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, options: .nonRepeating, value: failures)
            }
            switch error.fallback {
            case .downloadDMG:
                Text("You can download the update and install it from the DMG instead.")
                    .foregroundStyle(.secondary)
            case .releasePage:
                Text(
                    "BatteryPulse couldn't confirm this update came from its developer. Check the release page before installing anything."
                )
                .foregroundStyle(.secondary)
            case .none:
                EmptyView()
            }
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// What stops the app from installing the update itself: the failed installation's error, or
    /// the idle phase's blocker; `nil` when Install and Relaunch can be offered.
    private func problem(blocker: UpdateInstallError?) -> UpdateInstallError? {
        if case .failed(let error) = updater.installer.phase { return error }
        return blocker
    }

    /// Install and Relaunch when the app can replace itself, otherwise the browser download, or
    /// only the release page after a failed integrity check. Two rows, so the longer Russian
    /// labels fit the window.
    @ViewBuilder
    private func installActions(_ release: ReleaseInfo, blocker: UpdateInstallError?) -> some View {
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
                if let problem = problem(blocker: blocker) {
                    switch problem.fallback {
                    case .none:
                        // The new version is in place; it only has to be opened.
                        Button("Quit BatteryPulse") { NSApp.terminate(nil) }
                            .keyboardShortcut(.defaultAction)
                    case .releasePage:
                        // Never the default button: Return doesn't lead past a failed check.
                        Button("Open Release Page") { openReleasePage(release) }
                    case .downloadDMG:
                        if installer.canRetry {
                            Button("Try Again") { installer.install(release) }
                        }
                        Button("Download") { download(release) }
                            .keyboardShortcut(.defaultAction)
                    }
                } else {
                    Button("Download") { download(release) }
                    Button("Install and Relaunch") { installer.install(release) }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    /// The DMG in the browser: the fallback when the app can't install the update itself.
    private func download(_ release: ReleaseInfo) {
        updater.download(release)
        close()
    }

    /// The release page in the browser, after the DMG failed an integrity check.
    private func openReleasePage(_ release: ReleaseInfo) {
        updater.openReleasePage(release)
        close()
    }

    private func close() {
        dismissWindow(id: WindowID.update)
    }
}

/// The release notes, scrollable and selectable. Its inputs stay the same while a download
/// updates the window five times a second, so SwiftUI skips its body instead of parsing the
/// notes again on every step.
private struct ReleaseNotesText: View {
    let notes: String
    /// The release page, which relative links resolve against.
    let baseURL: URL

    var body: some View {
        ScrollView {
            Text(Self.notes(notes, baseURL: baseURL))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                // A link opens only over https; anything else does nothing.
                .environment(
                    \.openURL,
                    OpenURLAction { url in
                        ReleaseNotes.isAllowedLink(url) ? .systemAction : .discarded
                    })
        }
        .frame(height: 220)
        .background(.background.secondary, in: .rect(cornerRadius: 10, style: .continuous))
    }

    /// GitHub Markdown as attributed text: inline syntax only, with headings as bold lines.
    static func notes(_ notes: String, baseURL: URL) -> AttributedString {
        let markdown = ReleaseNotes.inlineMarkdown(notes)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        return (try? AttributedString(markdown: markdown, options: options, baseURL: baseURL))
            ?? AttributedString(notes)
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
    nonisolated static let version = AppVersion(parts: [0, 6, 0])

    struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    static let features: [Feature] = [
        Feature(
            id: 1, symbol: "ipad.and.iphone", title: "iPhone and iPad",
            detail:
                "Turn on Read iPhone and iPad batteries in Settings to see a connected device's maximum capacity, cycles and charge, with its history next to the Mac's."
        ),
        Feature(
            id: 2, symbol: "headphones", title: "Accessory batteries",
            detail:
                "Bluetooth keyboards, mice, trackpads and headphones in the menu bar panel and on the Accessories page, with an optional low-battery notification."
        ),
        Feature(
            id: 3, symbol: "macwindow", title: "Window styles",
            detail:
                "Choose Frosted in Settings → General to let the desktop show through. Translucent and Clear are in beta: turn on Beta window styles in Settings → Advanced."
        ),
        Feature(
            id: 4, symbol: "menubar.rectangle", title: "Menu bar icons like macOS 27",
            detail:
                "Every icon style now has the size and bolt of the system's battery icon, and Percentage Inside shows the charge the way macOS does."
        ),
        Feature(
            id: 5, symbol: "square.and.arrow.up", title: "Export history",
            detail:
                "Save the minute readings or the daily battery health as CSV for a spreadsheet, or all of it as JSON."),
    ]
}
#endif

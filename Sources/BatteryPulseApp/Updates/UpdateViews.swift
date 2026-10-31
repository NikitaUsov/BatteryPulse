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
    /// The version that ran before this launch, which decides whether the version count's row
    /// shows (``WhatsNew/features(after:)``).
    let previous: AppVersion?
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
                ForEach(Array(WhatsNew.features(after: previous).enumerated()), id: \.element.id) { index, feature in
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
enum WhatsNew {
    /// The version these features arrived in; What's New appears once after updating to it or
    /// past it, and not again for later bug-fix releases.
    nonisolated static let version = AppVersion(parts: [0, 7, 0])

    struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    static let features: [Feature] = [
        Feature(
            id: 1, symbol: "square.grid.2x2", title: "Widgets you configure",
            detail:
                "Control-click the Battery widget and choose Edit Widget to pick what it shows, now in a large size too. A placed widget keeps its look, and a click opens the matching page."
        ),
        Feature(
            id: 2, symbol: "keyboard", title: "Accessories widget",
            detail:
                "Your keyboard's, mouse's, trackpad's and headphones' batteries at a glance, in small, medium and large."
        ),
        Feature(
            id: 3, symbol: "battery.75percent", title: "Charged to limit",
            detail:
                "When the Charge Limit in System Settings → Battery stops charging, BatteryPulse says so in the app, its menu bar panel and the Battery widget."
        ),
    ]

    /// The anonymous version count, which arrived in 0.7.0 (``VersionCounterPolicy/introducedIn``).
    /// Its id is one no list of features uses.
    static let versionCount = Feature(
        id: 100, symbol: "chart.bar", title: "Anonymous version count",
        detail:
            "Once per version, BatteryPulse downloads a tiny file from GitHub, so its download count shows how many Macs use each version. No identifier and nothing about your Mac is sent; GitHub sees only what it sees for the update check. Turn it off in Settings → General."
    )

    /// The rows after an update from `previous`, `nil` when no earlier version ran: ``features``,
    /// then the version count's row. That row is one of the features while they are 0.7.0's (or
    /// an earlier list's); a later release keeps it for anyone updating from a version before the
    /// count, so a jump from 0.6 straight past 0.7 still announces it.
    static func features(after previous: AppVersion?) -> [Feature] {
        let announcesCount =
            version <= VersionCounterPolicy.introducedIn || VersionCounterPolicy.showsAnnouncement(previous: previous)
        return announcesCount ? features + [versionCount] : features
    }
}
#endif

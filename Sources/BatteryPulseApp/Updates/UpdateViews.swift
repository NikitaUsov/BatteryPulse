#if os(macOS)
import BatteryCore
import SwiftUI

/// The Software Update window: checking, up to date, failed, or a new version with its notes.
struct UpdateView: View {
    @Environment(UpdateChecker.self) private var updater
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            AppIconView()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(width: 540)
        .trackedWindow(WindowID.update)
    }

    @ViewBuilder
    private var content: some View {
        let current = updater.currentVersion.description
        switch updater.status {
        case .idle, .checking:
            Text("Checking for Updates…")
                .font(.title3.weight(.semibold))
            ProgressView()
                .progressViewStyle(.linear)
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
        case .failed:
            Text("Couldn't Check for Updates")
                .font(.title3.weight(.semibold))
            Text("Check your internet connection and try again.")
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
            Text(
                "Open the downloaded DMG and drag BatteryPulse to Applications to replace this copy. macOS asks once in Privacy & Security before the new version opens."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
                Button("Download") {
                    updater.download(release)
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func notes(_ release: ReleaseInfo) -> AttributedString {
        let markdown = ReleaseNotes.inlineMarkdown(release.notes)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(release.notes)
    }

    private func close() {
        dismissWindow(id: WindowID.update)
    }
}

/// Shown once after an update: what this version adds.
struct WhatsNewView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 22) {
            AppIconView()
                .frame(width: 88, height: 88)
            Text("What's New in BatteryPulse")
                .font(.title.weight(.semibold))
            VStack(alignment: .leading, spacing: 16) {
                ForEach(WhatsNew.features) { feature in
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
                }
            }
            Button("Continue") { dismissWindow(id: WindowID.whatsNew) }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(32)
        .frame(width: 520)
        .trackedWindow(WindowID.whatsNew)
    }
}

/// The features of this version, for What's New.
@MainActor
enum WhatsNew {
    struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    static let features: [Feature] = [
        Feature(
            id: 1, symbol: "sidebar.trailing", title: "Raw Data inspector",
            detail: "Double-click a row in Raw Data to read its full value, decoding and description."),
        Feature(
            id: 2, symbol: "arrow.down.circle", title: "Update check",
            detail: "BatteryPulse looks for a new version once a day. Turn it off in Settings → General."),
    ]
}
#endif

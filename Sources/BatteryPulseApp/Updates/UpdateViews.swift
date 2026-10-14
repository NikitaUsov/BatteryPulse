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
    /// The version these features arrived in; What's New appears once after updating to it or
    /// past it, and not again for later bug-fix releases.
    nonisolated static let version = AppVersion(parts: [0, 3, 0])

    struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
    }

    static let features: [Feature] = [
        Feature(
            id: 1, symbol: "chart.xyaxis.line", title: "History",
            detail: "Charge, power and temperature over the last 24 hours or 7 days, with figures for the period."),
        Feature(
            id: 2, symbol: "thermometer.medium", title: "Temperature and cells",
            detail: "The battery's temperature and the voltage of each cell, on the Health and Power pages."),
        Feature(
            id: 3, symbol: "bell.badge", title: "Notifications",
            detail: "When the battery reaches a charge level, runs low, needs service or the Mac gets hot."),
        Feature(
            id: 4, symbol: "widget.small", title: "Widget",
            detail: "Charge and battery health on the desktop or in Notification Center."),
        Feature(
            id: 5, symbol: "rectangle.compress.vertical", title: "Compact window",
            detail: "A small window with just the essentials. Switch in Settings → General."),
        Feature(
            id: 6, symbol: "sidebar.trailing", title: "Raw Data inspector",
            detail: "Double-click a row in Raw Data to read its full value, decoding and description."),
        Feature(
            id: 7, symbol: "arrow.down.circle", title: "Update check",
            detail: "BatteryPulse looks for a new version once a day. Turn it off in Settings → General."),
    ]
}
#endif

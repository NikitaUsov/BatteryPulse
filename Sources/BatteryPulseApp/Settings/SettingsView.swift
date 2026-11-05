#if os(macOS)
import AppKit
import BatteryCore
import Observation
import SwiftUI

/// The Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                SettingsPage {
                    GeneralSettings(includesWindowStyle: true)
                    DeviceSettings()
                }
            }
            Tab("Menu Bar", systemImage: "menubar.rectangle") {
                SettingsPage { MenuBarSettings() }
            }
            Tab("Notifications", systemImage: "bell.badge") {
                SettingsPage { NotificationSettings() }
            }
            Tab("Advanced", systemImage: "wrench.and.screwdriver") {
                SettingsPage { AdvancedSettings() }
            }
        }
        .frame(width: 500)
        .trackedWindow(WindowID.settings)
    }
}

/// A pane's grouped Form, as tall as its rows while it fits the screen: the Settings tabs and the
/// welcome window's settings. Above `SettingsPageFit`'s cap for its window it keeps the cap's
/// height and scrolls; it bounces only then.
struct SettingsPage<Content: View>: View {
    /// The window around the page.
    var fit = SettingsPageFit.settings
    @ViewBuilder let content: Content

    var body: some View {
        // Read here, on the main actor: the layout gets a plain number.
        let cap = fit.cap(visibleHeights: ScreenHeights.shared.visibleHeights)
        CappedHeightLayout(cap: CGFloat(cap)) {
            Form { content }
                .formStyle(.grouped)
                .scrollBounceBehavior(.basedOnSize)
        }
        // Again when a page shows, in case a change of the screens' room went unannounced.
        .onAppear { ScreenHeights.shared.update() }
    }
}

/// Gives its one subview the subview's ideal height for the proposed width, as
/// `fixedSize(horizontal: false, vertical: true)` would, up to `cap`, and the cap above it. Its
/// height never depends on the height proposed, so a window that sizes to its content takes it.
///
/// Nonisolated, as `Layout` requires: its requirements are nonisolated, and SwiftUI may lay out
/// off the main actor.
private nonisolated struct CappedHeightLayout: Layout {
    var cap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let page = subviews.first else { return .zero }
        // No height: the page's ideal one, as tall as its rows.
        let ideal = page.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        let height = SettingsPageFit.height(ideal: Double(ideal.height), cap: Double(cap))
        return CGSize(width: ideal.width, height: CGFloat(height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}

/// The visible heights of the screens (each one's area without the menu bar and the Dock), read
/// again when the displays change: one connected or removed, a new resolution, the Dock's room.
@Observable
final class ScreenHeights {
    static let shared = ScreenHeights()

    private(set) var visibleHeights: [Double] = []
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    private init() {
        update()
        // The app keeps the observer for its whole life.
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }

    /// Reads the heights again; the pages follow only a change.
    func update() {
        let heights = NSScreen.screens.map { Double($0.visibleFrame.height) }
        if heights != visibleHeights { visibleHeights = heights }
    }
}

/// Two alternatives in one place, such as a note that depends on a setting: switching crossfades
/// between them. Both keep their space, so the height never changes and the windows that size to
/// their content (Settings, Welcome) don't jump. VoiceOver reads only the one shown.
struct Crossfade<First: View, Second: View>: View {
    private let showsFirst: Bool
    private let first: First
    private let second: Second
    @Environment(\.motion) private var motion

    init(
        showsFirst: Bool, @ViewBuilder _ first: () -> First, @ViewBuilder otherwise second: () -> Second
    ) {
        self.showsFirst = showsFirst
        self.first = first()
        self.second = second()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            first
                .opacity(showsFirst ? 1 : 0)
                .accessibilityHidden(!showsFirst)
            second
                .opacity(showsFirst ? 0 : 1)
                .accessibilityHidden(showsFirst)
        }
        // Only opacity changes, so it fades under Reduce Motion too.
        .animation(motion.crossfade, value: showsFirst)
    }
}
#endif

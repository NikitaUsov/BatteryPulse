#if os(macOS)
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

private struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
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

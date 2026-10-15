#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

// The window style (Settings → General) of the main and compact windows: Standard, Frosted,
// Translucent or Clear. `WindowLookPolicy` (BatteryCore) decides what each draws; this file is
// the only place that changes a window's background, and `MotionGuardTests` keeps it that way.
//
// Only the background differs in view structure between the styles. Switching it rebuilds the
// window's content, which happens only when the person changes the setting or an accessibility
// setting; the main window's page survives in scene storage. Everything else (the policy, the
// tones) reaches the content as values. Nothing here animates: a background swap is not a motion
// event, and a crossfade of materials would cost a blur pass per frame.

extension EnvironmentValues {
    /// What this window draws. `.windowLook()` sets it on the main and compact windows; every
    /// other window stays Standard.
    @Entry var windowLook = WindowLookPolicy.standard
}

extension View {
    /// Applies the window style setting to this window: its background, and the policy and tones
    /// its content reads. Apply it once at the root of the main and compact windows, inside
    /// `.motionPolicy()`.
    func windowLook() -> some View {
        modifier(WindowLookModifier())
    }
}

private struct WindowLookModifier: ViewModifier {
    @AppStorage(AppSettings.windowLookKey) private var stored = WindowLook.standard
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let policy = WindowLookPolicy(
            setting: stored, reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
        content
            .environment(\.windowLook, policy)
            .environment(\.tones, policy.tones)
            .modifier(WindowBackground(policy: policy))
    }
}

/// The window background, the one part whose structure differs between styles.
private struct WindowBackground: ViewModifier {
    let policy: WindowLookPolicy

    @ViewBuilder
    func body(content: Content) -> some View {
        switch policy.background {
        case .system:
            // Standard: the window as the system draws it.
            content
        case .material:
            // Frosted: a standard material behind the window, as Apple asks for app backgrounds
            // in the content layer (not Liquid Glass). It stays active when the window is
            // inactive: the frost is the point of the choice. Labels on it render vibrant.
            content
                .environment(\.backgroundMaterial, .regular)
                .containerBackground(
                    Material.regular.materialActiveAppearance(policy.keepsMaterialActive ? .active : .automatic),
                    for: .window)
        case .glassSheet:
            content
        }
    }
}
#endif

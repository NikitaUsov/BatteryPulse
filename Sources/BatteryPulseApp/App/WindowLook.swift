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
// setting; the main window's page survives in scene storage, and the window's registrations (live
// refresh, the Dock icon policy) sit outside the modifier, so a rebuild never drops or repeats
// them. Everything else (the policy, the tones) reaches the content as values. Nothing here animates: a background swap is not a motion
// event, and a crossfade of materials would cost a blur pass per frame.

extension EnvironmentValues {
    /// What this window draws. `.windowLook()` sets it on the main and compact windows; every
    /// other window stays Standard.
    @Entry var windowLook = WindowLookPolicy.standard
    /// Clear's shadow and halo under each group of white content; `nil` in the other styles, and
    /// inside a group that already has it.
    @Entry var contentTreatment: ContentTreatment? = nil
}

extension View {
    /// Applies the window style setting to this window: its background, and the policy and tones
    /// its content reads. Apply it once at the root of the main and compact windows, inside
    /// `.motionPolicy()`, `.liveRefresh(…)` and `.trackedWindow(_:)`: a style change rebuilds what
    /// it wraps, which would run their appear and disappear actions in an undefined order.
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
        // Only the glass sheet's tint and Clear's treatment depend on the system appearance; the
        // other styles never start observing it.
        let systemDark = policy.usesGlassSheet && SystemAppearance.shared.isDark
        content
            .environment(\.windowLook, policy)
            .environment(\.tones, policy.tones)
            .environment(\.contentTreatment, policy.contentTreatment(systemDark: systemDark))
            // Clear: system controls that take a tint (the selected segment, a prominent button,
            // the sidebar's selection if it reaches it) turn a neutral graphite, never white:
            // macOS draws white labels on tinted fills. `nil` keeps the accent colour.
            .tint(policy.tones.controlTintColor)
            .modifier(WindowBackground(policy: policy, systemDark: systemDark))
            // Outside the background's branches, so it keeps its identity and gives the window
            // back the system appearance when Clear is turned off.
            .background { WindowAppearanceSetter(dark: policy.forcesDarkAppearance) }
    }
}

/// The window background, the one part whose structure differs between styles.
private struct WindowBackground: ViewModifier {
    let policy: WindowLookPolicy
    let systemDark: Bool

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
            // Translucent and Clear: one sheet of clear glass behind the sidebar, the toolbar and
            // the content, tinted with Translucent's dimming layer or Clear's faint tone.
            content.containerBackground(for: .window) {
                GlassSheet(tint: policy.sheetTint(systemDark: systemDark).map { Color($0) })
            }
        }
    }
}

/// One sheet of clear Liquid Glass behind the whole window. Never animated, never interactive,
/// one per window. The system's sidebar, toolbar and inspector, and the Demo Mode bar, are the
/// only glass on top of it; nothing in the content is glass.
private struct GlassSheet: View {
    let tint: Color?

    var body: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(Glass.clear.tint(tint), in: .rect)
            .ignoresSafeArea()
    }
}

/// Puts its window in the dark appearance while `dark` is true (Clear: content is white in Light
/// and Dark, so the system's text, symbols and controls must be too) and gives it back the
/// system appearance when it turns false, while the view is still in the window. Only this
/// window: Settings and the menu bar panel keep the system appearance.
private struct WindowAppearanceSetter: NSViewRepresentable {
    let dark: Bool

    func makeNSView(context: Context) -> AppearanceView {
        let view = AppearanceView()
        view.isDark = dark
        return view
    }

    func updateNSView(_ view: AppearanceView, context: Context) {
        view.isDark = dark
    }

    final class AppearanceView: NSView {
        var isDark = false {
            didSet {
                if isDark != oldValue { apply() }
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else { return }
            if isDark {
                if window.appearance?.name != .darkAqua { window.appearance = NSAppearance(named: .darkAqua) }
            } else if window.appearance != nil {
                window.appearance = nil
            }
        }

        /// Never takes a click from the content above it.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

extension Color {
    /// A colour-neutral tint from the window look policy.
    fileprivate init(_ tint: WindowLookPolicy.Tint) {
        self.init(white: tint.white, opacity: tint.opacity)
    }
}

/// The system's appearance, Light or Dark, read from the app rather than from a window: a Clear
/// window is in the dark appearance whatever the system's, while its glass tone follows the
/// system's (Light, Dark or Auto, as the system's own Clear style).
@MainActor
@Observable
final class SystemAppearance {
    static let shared = SystemAppearance()

    private(set) var isDark: Bool
    @ObservationIgnored private var observation: NSKeyValueObservation?

    private init() {
        isDark = Self.readIsDark()
        // The app keeps one observation for its whole life.
        observation = NSApp.observe(\.effectiveAppearance) { _, _ in
            Task { @MainActor in SystemAppearance.shared.update() }
        }
    }

    private func update() {
        let isDark = Self.readIsDark()
        if self.isDark != isDark { self.isDark = isDark }
    }

    private static func readIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
#endif

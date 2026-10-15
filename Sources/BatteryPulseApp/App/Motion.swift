#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import Observation
import SwiftUI

// Motion in BatteryPulse: every animation is triggered by an event, plays once and lasts
// 0.15–0.35 s. It is keyed on `BatteryMotionKey` or on UI state, never on the snapshot (which
// changes with every 2 s reading), and it goes through `\.motion`, so Reduce Motion turns it into
// a fade and a hidden window animates nothing. `MotionGuardTests` checks the sources for the
// rest: no repeating or per-frame animation, no animation that bypasses `\.motion`, nothing in
// the menu bar label.
//
// Under Reduce Motion nothing moves. SwiftUI doesn't drop explicit animations for it, and an
// animation on a container animates every frame in it, so the presets split by what they may
// animate: `change` moves things and is `nil` under Reduce Motion (the layout snaps into place),
// `crossfade` only fades and stays. A view that appears or goes while the layout around it
// changes carries its own fade (`insertion(edge:)`, `fadeTransition`), so it still fades while
// its neighbours snap.

extension EnvironmentValues {
    /// How much this window animates. `.motionPolicy()` sets it at the root of every window and
    /// of the menu bar panel; views read it with `@Environment(\.motion) private var motion` and
    /// animate only through its presets.
    @Entry var motion = MotionPolicy()
}

// MARK: - Presets

/// The app's animations and transitions for each ``MotionPolicy/Level``.
///
/// | Preset | `.full` | `.fade` (Reduce Motion) | `.none` (hidden window) |
/// |---|---|---|---|
/// | ``change`` | smooth, 0.35 s | `nil`: the layout snaps | `nil` |
/// | ``crossfade`` | smooth, 0.35 s | ease in-out, 0.2 s | `nil` |
/// | ``numbers`` | smooth, 0.25 s | as ``crossfade`` | `nil` |
/// | ``quickFade`` | ease in-out, 0.15 s | the same | `nil` |
/// | ``linear(_:)`` | linear | `nil` | `nil` |
/// | ``insertion(edge:)`` | move from `edge` + opacity | opacity with ``crossfade`` | opacity |
/// | ``fadeTransition`` | opacity with ``crossfade`` | the same | opacity |
/// | ``replacement`` | fades in, goes at once | the same | at once |
/// | ``symbolSwap`` | symbol Replace | opacity | identity |
/// | ``boltTransition`` | symbol Draw On | opacity | opacity |
extension MotionPolicy {
    /// State changes that move or resize something: plugging in, a new charge state, a row or
    /// section appearing, a ring or a bar growing, a container whose layout changes. `nil` under
    /// Reduce Motion, so the layout snaps into place; give the view that appears or goes its own
    /// fade (``insertion(edge:)``, ``fadeTransition``).
    var change: Animation? {
        allowsMovement ? .smooth(duration: 0.35) : nil
    }

    /// Changes of opacity or colour only: a tint, a symbol or a label swapping in place, content
    /// fading in a frame that keeps its size. Under Reduce Motion a 0.2 s fade. Never on a view
    /// whose size or position changes in the same update; that takes ``change``.
    var crossfade: Animation? {
        switch level {
        case .full: .smooth(duration: 0.35)
        case .fade: .easeInOut(duration: 0.2)
        case .none: nil
        }
    }

    /// Numbers rolling to their new value; see `numericValue(_:)`.
    var numbers: Animation? {
        level == .full ? .smooth(duration: 0.25) : crossfade
    }

    /// Frequent switches, such as the main window's pages: a short fade, never movement.
    var quickFade: Animation? {
        level == .none ? nil : .easeInOut(duration: 0.15)
    }

    /// One step of a value that changes continuously, such as a frame of Demo Mode's charge and
    /// drain animations: linear over `duration` seconds, up to the next step. Under Reduce
    /// Motion each step lands at once.
    func linear(_ duration: Double) -> Animation? {
        allowsMovement ? .linear(duration: duration) : nil
    }

    /// A view that comes with an event (the adapter when plugging in) slides in from `edge`.
    /// Under Reduce Motion it fades with an animation of its own while the views around it snap
    /// into place. Main actor, like the views that use it.
    @MainActor func insertion(edge: Edge) -> AnyTransition {
        allowsMovement ? .move(edge: edge).combined(with: .opacity) : AnyTransition.opacity.animation(crossfade)
    }

    /// A view that appears or goes with an event while the layout around it changes, such as the
    /// hero's time line: it fades with an animation of its own, so it still fades under Reduce
    /// Motion, where the change around it is not animated.
    @MainActor var fadeTransition: AnyTransition {
        AnyTransition.opacity.animation(crossfade)
    }

    /// Content that replaces other content in a window that sizes to its content (Software
    /// Update): the old content goes at once and the new one fades in where it lands. Nothing is
    /// laid out twice, so the window resizes once and the buttons below don't move back and
    /// forth.
    @MainActor var replacement: AnyTransition {
        .asymmetric(insertion: AnyTransition.opacity.animation(crossfade), removal: .identity)
    }

    /// One SF Symbol replacing another (`contentTransition`).
    var symbolSwap: ContentTransition {
        switch level {
        case .full: .symbolEffect(.replace)
        case .fade: .opacity
        case .none: .identity
        }
    }

    /// The charging bolt appearing and disappearing. Main actor, like the symbol effect it builds.
    @MainActor var boltTransition: AnyTransition {
        // If Draw On turns out not to suit `bolt.fill`, `.symbolEffect(.appear)` is the fallback.
        level == .full ? AnyTransition(.symbolEffect(.drawOn)) : .opacity
    }
}

// MARK: - Window root

extension View {
    /// Computes `\.motion` for this window: Reduce Motion, Prefer Cross-Fade Transitions, Low
    /// Power Mode, the system's request to save resources, and whether the window can be seen.
    /// While it can't, every animation in it is dropped, explicit `withAnimation` included.
    /// Apply it once at the root of each window, outside the root view, so the root view's own
    /// `@Environment(\.motion)` sees it too.
    func motionPolicy() -> some View {
        modifier(MotionPolicyModifier())
    }

    /// Rolls a number to its new value in the direction of the change, keyed on `value` rounded to
    /// a whole number (the number the text shows, e.g. a percentage). Under Reduce Motion the
    /// text fades; in a hidden window it changes instantly.
    func numericValue(_ value: Double?) -> some View {
        modifier(NumericValueModifier(value: value))
    }

    /// Requests polling at `interval` from `monitor` while this view is on screen, its window is
    /// visible and `isEnabled` is true; withdraws the request otherwise.
    func liveRefresh(
        _ monitor: BatteryMonitor, every interval: Duration, client: String, isEnabled: Bool = true
    ) -> some View {
        modifier(LiveRefreshModifier(monitor: monitor, interval: interval, client: client, isEnabled: isEnabled))
    }
}

private struct MotionPolicyModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // macOS 26.4. On macOS it returns the Reduce Motion setting.
    @Environment(\.accessibilityPrefersCrossFadeTransitions) private var prefersCrossFade
    // macOS 27.
    @Environment(\.systemPrefersReducedResourceUsage) private var systemPrefersReducedResourceUsage
    @State private var isVisible = true

    func body(content: Content) -> some View {
        let policy = MotionPolicy(
            reduceMotion: reduceMotion,
            prefersCrossFade: prefersCrossFade,
            isVisible: isVisible,
            reducesResources: LowPowerMode.shared.isEnabled || systemPrefersReducedResourceUsage)
        let isHidden = !isVisible
        content
            .environment(\.motion, policy)
            .transaction { transaction in
                guard isHidden else { return }
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            .background(WindowVisibilityReader(isVisible: $isVisible))
    }
}

private struct NumericValueModifier: ViewModifier {
    let value: Double?
    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        let rounded = value.map { $0.rounded(.toNearestOrEven) }
        content
            .contentTransition(transition(for: rounded))
            .animation(motion.numbers, value: rounded)
    }

    private func transition(for value: Double?) -> ContentTransition {
        switch motion.level {
        case .full: value.map(ContentTransition.numericText(value:)) ?? .numericText()
        case .fade: .opacity
        case .none: .identity
        }
    }
}

private struct LiveRefreshModifier: ViewModifier {
    let monitor: BatteryMonitor
    let interval: Duration
    let client: String
    let isEnabled: Bool
    @Environment(\.motion) private var motion

    /// The interval this view asks for right now, or `nil` for none.
    private var request: Duration? {
        isEnabled && motion.isVisible ? interval : nil
    }

    func body(content: Content) -> some View {
        content
            .onAppear { monitor.setLiveRefreshInterval(request, for: client) }
            .onChange(of: request) { _, request in monitor.setLiveRefreshInterval(request, for: client) }
            .onDisappear { monitor.setLiveRefreshInterval(nil, for: client) }
    }
}

// MARK: - Inputs

/// Low Power Mode as macOS reports it. Read from `ProcessInfo` rather than the snapshot, so a
/// Demo Mode scene that simulates it doesn't change how the app animates.
@MainActor
@Observable
final class LowPowerMode {
    static let shared = LowPowerMode()

    private(set) var isEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        // The app keeps one observer for its whole life.
        observer = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let isEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                if self.isEnabled != isEnabled { self.isEnabled = isEnabled }
            }
        }
    }
}

/// Reports whether any part of the window that hosts it is on screen, from the window's
/// occlusion state: covered, minimized, on another Space, the display asleep or the screen saver
/// all count as hidden.
///
/// Per window, because the menu bar item keeps the whole app visible to macOS, so app-level
/// occlusion and App Nap never apply. Not `scenePhase` (its meaning on macOS is undocumented) and
/// not `appearsActive` (that means the key window, not a visible one).
private struct WindowVisibilityReader: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> OcclusionObservingView {
        let view = OcclusionObservingView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: OcclusionObservingView, context: Context) {
        let isVisible = $isVisible
        view.onChange = { visible in
            if isVisible.wrappedValue != visible { isVisible.wrappedValue = visible }
        }
    }

    final class OcclusionObservingView: NSView {
        var onChange: ((Bool) -> Void)?
        private weak var observedWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window !== observedWindow else { return }
            let center = NotificationCenter.default
            if let observedWindow {
                center.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: observedWindow)
            }
            observedWindow = window
            guard let window else { return }
            // Selector-based, so the observer goes away with the view. AppKit posts window
            // notifications on the main thread.
            center.addObserver(
                self, selector: #selector(occlusionStateDidChange(_:)),
                name: NSWindow.didChangeOcclusionStateNotification, object: window)
            // The window may not be on screen yet while SwiftUI builds it; read the state once
            // the current update is done, and rely on the notification after that.
            Task { [weak self] in self?.report() }
        }

        @objc private func occlusionStateDidChange(_ notification: Notification) {
            report()
        }

        private func report() {
            guard let window else { return }
            onChange?(window.occlusionState.contains(.visible))
        }

        /// Never takes a click from the content above it.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
#endif

#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

/// The status item: any combination of the battery icon, the charge, the battery power and the
/// battery temperature, in that order (``MenuBarContent``).
struct MenuBarLabel: View {
    let monitor: BatteryMonitor
    @Environment(DemoController.self) private var demo
    // The defaults of MenuBarContent: the icon and the charge.
    @AppStorage(AppSettings.menuBarShowsIconKey) private var showsIcon = true
    @AppStorage(AppSettings.menuBarShowsChargeKey) private var showsCharge = true
    @AppStorage(AppSettings.menuBarShowsPowerKey) private var showsPower = false
    @AppStorage(AppSettings.menuBarShowsTemperatureKey) private var showsTemperature = false
    @AppStorage(AppSettings.menuBarIconStyleKey) private var iconStyle = MenuBarIconStyle.default
    /// Whether the item is in the menu bar. A label that outlives the item's removal stops polling,
    /// and asks again when the item comes back.
    @AppStorage(AppSettings.showInMenuBarKey) private var isInserted = true
    @Environment(\.openWindow) private var openWindow
    // macOS 27. The label isn't inside `.motionPolicy()`, so it reads this itself.
    @Environment(\.systemPrefersReducedResourceUsage) private var systemPrefersReducedResourceUsage
    /// How many members of the label are on screen. The `Group`'s modifiers apply to each member,
    /// so one member going (the icon turned off, Demo Mode ending) must not withdraw the polling
    /// that the others still show; the last one going does.
    @State private var shownMembers = 0

    private var content: MenuBarContent {
        MenuBarContent(
            showsIcon: showsIcon, showsCharge: showsCharge, showsPower: showsPower, showsTemperature: showsTemperature)
    }

    /// How often the label asks for fresh readings, or `nil` for never: power changes without OS
    /// notifications, so it is polled gently while shown, and less often while the system asks
    /// to save energy (``LiveRefreshPolicy``). Low Power Mode and the thermal state come from
    /// `ProcessInfo`, never from the snapshot, which Demo Mode simulates.
    ///
    /// Nobody sees the label while the displays sleep or the session is switched out, so the
    /// request goes then; coming back asks again, which reads once. The OS's change
    /// notifications still update the battery meanwhile, and History keeps recording.
    private var liveRefreshRequest: Duration? {
        guard isInserted, ScreenActivity.shared.isActive, let base = content.liveRefreshInterval else { return nil }
        let power = SystemPowerState.shared
        return LiveRefreshPolicy.interval(
            base: base, reducesResources: power.isLowPowerModeEnabled || systemPrefersReducedResourceUsage,
            thermal: power.thermalState)
    }

    var body: some View {
        let snapshot = monitor.snapshot
        let title = content.title(for: snapshot, formatter: .app)
        Group {
            if demo.isActive {
                // The values next to it are simulated.
                Image(systemName: "play.rectangle.on.rectangle")
                    .accessibilityLabel("Demo Mode")
            }
            if content.showsIcon(title: title) {
                icon(for: snapshot)
            }
            if !title.isEmpty {
                Text(title)
            }
        }
        // Never animated: every state change swaps at once, Demo Mode's animated changes included.
        // See `icon(for:)` for why.
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .onAppear {
            shownMembers += 1
            WindowOpener.openWindow = openWindow
            Diagnostics.menuBarAppeared()
        }
        .onChange(of: liveRefreshRequest, initial: true) { _, interval in
            monitor.setLiveRefreshInterval(interval, for: "menuBar")
        }
        .onDisappear {
            shownMembers -= 1
            if shownMembers == 0 { monitor.setLiveRefreshInterval(nil, for: "menuBar") }
        }
    }

    /// A drawn battery rendered to an image, since the status item doesn't reliably draw shapes;
    /// the SF Symbol for that style, or if rendering fails.
    ///
    /// No animation, by design: every frame of one would be another `ImageRenderer` pass (two
    /// while the icon is tinted red or yellow), the one-entry cache in `MenuBarIconRenderer` would
    /// miss on every frame, and the status item is always on screen, so it would cost energy all
    /// day. `MotionGuardTests` keeps this file free of animations.
    @ViewBuilder
    private func icon(for snapshot: BatterySnapshot?) -> some View {
        let state = BatteryIconState(snapshot: snapshot)
        let description = Phrases.batteryIcon(snapshot, .app)
        if let image = MenuBarIconRenderer.image(style: iconStyle, state: state) {
            Image(nsImage: image)
                .renderingMode(state.isMonochrome ? .template : .original)
                .accessibilityLabel(description)
        } else {
            Image(systemName: BatteryPresentation.symbolName(for: snapshot))
                .accessibilityLabel(description)
        }
    }
}
#endif

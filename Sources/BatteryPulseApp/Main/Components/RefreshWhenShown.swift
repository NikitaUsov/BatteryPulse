#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI

extension View {
    /// One accessory read each time this view's window becomes visible. The menu bar panel's
    /// content stays alive between openings, so `onAppear` alone would not repeat; this follows
    /// `motion.isVisible`, as `liveRefresh` does. It catches anything missed over sleep.
    func refreshesWhenShown(_ monitor: AccessoryMonitor) -> some View {
        modifier(RefreshWhenShown(monitor: monitor))
    }
}

private struct RefreshWhenShown: ViewModifier {
    let monitor: AccessoryMonitor
    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        content
            .onChange(of: motion.isVisible, initial: true) { _, isVisible in
                if isVisible { monitor.refresh() }
            }
    }
}
#endif

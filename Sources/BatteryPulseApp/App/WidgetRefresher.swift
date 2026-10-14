#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import Observation
import WidgetKit

/// Asks WidgetKit to reload the battery widget when the battery changes enough to matter
/// (``WidgetReloadPolicy``). The widget reads the battery itself; this only says when. Demo
/// Mode never reaches the widget.
@MainActor
final class WidgetRefresher {
    private let monitor: BatteryMonitor
    private var policy = WidgetReloadPolicy()

    init(monitor: BatteryMonitor) {
        self.monitor = monitor
    }

    func start() {
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = monitor.snapshot
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.evaluate()
                self?.observe()
            }
        }
    }

    private func evaluate() {
        guard !monitor.isOverridden, let snapshot = monitor.snapshot,
            policy.shouldReload(for: snapshot, at: .now)
        else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: BatteryWidgetKind.battery)
    }
}
#endif

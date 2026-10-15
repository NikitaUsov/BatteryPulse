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

    /// Ends the widget extension left running by the previous version. After the app is replaced
    /// (Install and Relaunch, or a new copy from the DMG), WidgetKit keeps sending requests to the
    /// extension process that is already running and rejects every timeline it returns, because
    /// its bundle version no longer matches the installed one: the widget stays frozen, then goes
    /// blank. WidgetKit starts the new extension on the next request, which follows here.
    static func endPreviousExtension() {
        var pids = [pid_t](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard count > 0 else { return }
        var ended = false
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var name = [CChar](repeating: 0, count: 64)
            guard proc_name(pid, &name, UInt32(name.count)) > 0 else { continue }
            let processName = String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            // Another user's copy can't be signalled anyway.
            if processName == extensionExecutable, kill(pid, SIGTERM) == 0 { ended = true }
        }
        guard ended else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// `CFBundleExecutable` of `BatteryPulseWidget.appex` (scripts/build-app.sh).
    private static let extensionExecutable = "BatteryPulseWidget"

    private func evaluate() {
        guard !monitor.isOverridden, let snapshot = monitor.snapshot,
            policy.shouldReload(for: snapshot, at: .now)
        else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: BatteryWidgetKind.battery)
    }
}
#endif

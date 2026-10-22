#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import Observation
import WidgetKit
import os

/// Asks WidgetKit to reload the battery widget when the battery changes enough to matter
/// (``WidgetReloadPolicy``). The widget reads the battery itself; this only says when. Demo
/// Mode never reaches the widget.
@MainActor
final class WidgetRefresher {
    private let monitor: BatteryMonitor
    private var policy = WidgetReloadPolicy()
    private var observation: Task<Void, Never>?

    init(monitor: BatteryMonitor) {
        self.monitor = monitor
    }

    /// Evaluates every change of the monitor's snapshot. The snapshot at the start is no change,
    /// so a launch doesn't reload the widget.
    func start() {
        guard observation == nil else { return }
        observation = Task(name: "WidgetRefresher.observation") { [weak self, monitor] in
            for await _ in Observations({ monitor.snapshot }).dropFirst() {
                guard let self else { return }
                self.evaluate()
            }
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
    }

    /// Ends the widget extension left running by the previous version. After the app is replaced
    /// (Install and Relaunch, or a new copy from the DMG), WidgetKit keeps sending requests to the
    /// extension process that is already running and rejects every timeline it returns, because
    /// its bundle version no longer matches the installed one: the widget stays frozen, then goes
    /// blank. WidgetKit starts the new extension on the next request, which follows here.
    static func endPreviousExtension() {
        var pids = [pid_t](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard count > 0 else {
            Diagnostics.widget.error("Listing the processes failed; the previous widget extension may still run")
            return
        }
        var ended = false
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var name = [CChar](repeating: 0, count: 64)
            guard proc_name(pid, &name, UInt32(name.count)) > 0 else { continue }
            let processName = String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            // Another user's copy can't be signalled anyway.
            if processName == extensionExecutable, kill(pid, SIGTERM) == 0 { ended = true }
        }
        guard ended else { return }
        Diagnostics.widget.notice("Ended the previous version's widget extension")
        // Main actor already: the class is.
        Task {
            try? await Task.sleep(for: .seconds(1))
            WidgetCenter.shared.reloadAllTimelines()
            Diagnostics.event("widget.reload", trigger: "update")
            Diagnostics.widget.notice("Reloading the widget after an update")
        }
    }

    /// `CFBundleExecutable` of `BatteryPulseWidget.appex` (scripts/build-app.sh).
    private static let extensionExecutable = "BatteryPulseWidget"

    private func evaluate() {
        guard !monitor.isOverridden, let snapshot = monitor.snapshot,
            policy.shouldReload(for: snapshot, at: .now)
        else { return }
        // SPIKE-W (W0-3): the feed first, so the reloaded widget reads this write.
        SpikeWidgetFeed.write()
        WidgetCenter.shared.reloadTimelines(ofKind: BatteryWidgetKind.battery)
        Diagnostics.event("widget.reload", trigger: "policy")
        // One line per reload, so `log show` counts a day's reloads against WidgetKit's budget.
        let percent = snapshot.chargePercent.map { String(Int($0.rounded())) } ?? "-"
        Diagnostics.widget.notice(
            "Reloading the widget: \(snapshot.chargeState.rawValue, privacy: .public), \(percent, privacy: .public)%")
    }
}
#endif

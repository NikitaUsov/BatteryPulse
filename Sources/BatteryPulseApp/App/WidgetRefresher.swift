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
    /// blank. WidgetKit starts the new extension on the next request, which follows here. After an
    /// in-app install, ``endExtensionBeforeSwap()`` has usually ended it already, and this finds
    /// nothing, or the new extension WidgetKit started meanwhile, which a reload brings back.
    static func endPreviousExtension() {
        guard let processes = extensionProcesses() else {
            Diagnostics.widget.error("Listing the processes failed; the previous widget extension may still run")
            return
        }
        var ended = false
        // Another user's copy can't be signalled anyway.
        for pid in processes where kill(pid, SIGTERM) == 0 { ended = true }
        guard ended else { return }
        Diagnostics.widget.notice("Ended the previous version's widget extension")
        // On the main actor, like the rest of the app.
        Task {
            try? await Task.sleep(for: .seconds(1))
            WidgetCenter.shared.reloadAllTimelines()
            Diagnostics.event("widget.reload", trigger: "update")
            Diagnostics.widget.notice("Reloading the widget after an update")
        }
    }

    /// Ends the running widget extension right before an update swaps the app. At the version
    /// change WidgetKit fetches the widget descriptors again within milliseconds, and an
    /// extension of the previous version still running answers with the previous descriptor,
    /// which WidgetKit then keeps: when the update changes the descriptor, every placed widget
    /// greys out. ``endPreviousExtension()`` runs only at the new version's launch, too late.
    ///
    /// Sends SIGTERM to every extension process, polls every 50 ms, sends SIGKILL to one still
    /// there 0.5 s after its SIGTERM (a process started meanwhile gets its own SIGTERM at the next
    /// poll), and gives up after 1.5 s. It never throws and never fails an install: the swap goes
    /// ahead either way. Nonisolated, so the installer's `@concurrent` swap calls it without a hop
    /// to the main actor.
    nonisolated static func endExtensionBeforeSwap() async {
        let clock = ContinuousClock()
        let start = clock.now
        // When each process got its SIGTERM, and which of them got a SIGKILL too.
        var waiting: [pid_t: ContinuousClock.Instant] = [:]
        var killed: Set<pid_t> = []
        var byTerm = 0
        var byKill = 0
        while true {
            guard let processes = extensionProcesses() else {
                Diagnostics.update.error("Listing the processes failed; the widget extension may run during the swap")
                break
            }
            for pid in waiting.keys.filter({ !processes.contains($0) }) {
                if killed.contains(pid) { byKill += 1 } else { byTerm += 1 }
                waiting[pid] = nil
            }
            let now = clock.now
            // Another user's copy can't be signalled, so it isn't waited for.
            for pid in processes where waiting[pid] == nil && kill(pid, SIGTERM) == 0 {
                waiting[pid] = now
            }
            for (pid, sent) in waiting where !killed.contains(pid) && now - sent >= .milliseconds(500) {
                if kill(pid, SIGKILL) == 0 { killed.insert(pid) }
            }
            guard !waiting.isEmpty, now - start < .milliseconds(1500) else { break }
            do {
                try await Task.sleep(for: .milliseconds(50), tolerance: .milliseconds(10))
            } catch {
                break
            }
        }
        let found = byTerm + byKill + waiting.count
        let left = waiting.count
        let elapsed = Int(((clock.now - start) / .milliseconds(1)).rounded())
        Diagnostics.update.notice(
            "Widget extension before the swap: \(found, privacy: .public) found, \(byTerm, privacy: .public) ended by SIGTERM, \(byKill, privacy: .public) by SIGKILL, \(left, privacy: .public) still running, \(elapsed, privacy: .public) ms"
        )
    }

    /// The process IDs of every widget extension process, or `nil` when the list can't be read.
    /// No ID, path or name of a process is logged.
    private nonisolated static func extensionProcesses() -> [pid_t]? {
        var pids = [pid_t](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard count > 0 else { return nil }
        var found: [pid_t] = []
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var name = [CChar](repeating: 0, count: 64)
            guard proc_name(pid, &name, UInt32(name.count)) > 0 else { continue }
            let processName = String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if processName == extensionExecutable { found.append(pid) }
        }
        return found
    }

    /// `CFBundleExecutable` of `BatteryPulseWidget.appex` (scripts/build-app.sh).
    private nonisolated static let extensionExecutable = "BatteryPulseWidget"

    private func evaluate() {
        guard !monitor.isOverridden, let snapshot = monitor.snapshot,
            policy.shouldReload(for: snapshot, at: .now)
        else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: BatteryWidgetKind.battery)
        Diagnostics.event("widget.reload", trigger: "policy")
        // One line per reload, so `log show` counts a day's reloads against WidgetKit's budget.
        let percent = snapshot.chargePercent.map { String(Int($0.rounded())) } ?? "-"
        Diagnostics.widget.notice(
            "Reloading the widget: \(snapshot.chargeState.rawValue, privacy: .public), \(percent, privacy: .public)%")
    }
}
#endif

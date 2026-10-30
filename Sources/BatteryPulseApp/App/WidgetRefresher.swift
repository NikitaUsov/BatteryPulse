#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import Observation
import WidgetKit
import os

/// Asks WidgetKit to reload a widget kind when what it shows changes enough to matter
/// (``WidgetReloadPlanner``), and only a kind someone placed (``WidgetPlacements``). The widgets
/// read the battery and the accessories themselves; this only says when. Demo Mode never reaches
/// the widgets.
final class WidgetRefresher {
    private let monitor: BatteryMonitor
    private let accessories: AccessoryMonitor
    private var planner = WidgetReloadPlanner()
    private var placements = WidgetPlacements()
    private var batteryObservation: Task<Void, Never>?
    private var accessoryObservation: Task<Void, Never>?

    init(monitor: BatteryMonitor, accessories: AccessoryMonitor) {
        self.monitor = monitor
        self.accessories = accessories
    }

    /// Evaluates every change of the battery and of the accessory list. The values at the start
    /// are no change: the planner records them as what the widgets show, so a launch reloads
    /// nothing.
    func start() {
        guard batteryObservation == nil else { return }
        if !isDemo {
            let now = Date.now
            if let snapshot = monitor.snapshot { _ = planner.battery(snapshot, at: now) }
            _ = planner.accessories(accessories.accessories, at: now)
        }
        batteryObservation = Task(name: "WidgetRefresher.battery") { [weak self, monitor] in
            for await _ in Observations({ monitor.snapshot }).dropFirst() {
                guard let self else { return }
                await self.evaluateBattery()
            }
        }
        accessoryObservation = Task(name: "WidgetRefresher.accessories") { [weak self, accessories] in
            for await _ in Observations({ accessories.accessories }).dropFirst() {
                guard let self else { return }
                await self.evaluateAccessories()
            }
        }
    }

    func stop() {
        batteryObservation?.cancel()
        batteryObservation = nil
        accessoryObservation?.cancel()
        accessoryObservation = nil
    }

    /// The app's effective language at its last launch (the first of
    /// `Bundle.main.preferredLocalizations`, "en" or "ru"), so a launch in another language
    /// reloads the widgets. A settings key
    /// of the app's domain since 0.7, whose name, type and meaning stay (RD C14 item 1); missing
    /// before the first launch of 0.7, which only stores it.
    static let lastSeenLanguageKey = "lastSeenLanguage"

    /// At a launch of another version or in another language, ends the widget extension a
    /// previous launch left running and reloads every kind, as
    /// ``WidgetReloadPlanner/launchReason(versionChanged:lastLanguage:language:)`` decides.
    ///
    /// After the app is replaced (Install and Relaunch, or a new copy from the DMG), WidgetKit keeps
    /// sending requests to the extension process that is already running and rejects every
    /// timeline it returns, because its bundle version no longer matches the installed one: the
    /// widget stays frozen, then goes blank. WidgetKit starts the new extension on the next
    /// request, which follows here. After an in-app install, ``endExtensionBeforeSwap()`` has
    /// usually ended it already, and this finds nothing, or the new extension WidgetKit started
    /// meanwhile, which a reload brings back.
    ///
    /// A language chosen for BatteryPulse alone (Settings → General → Language) applies at the next
    /// launch, and every placed widget keeps its render in the previous language until it
    /// reloads, so a language change reloads every kind even when no extension was running.
    static func endPreviousExtension(versionChanged: Bool) {
        let defaults = UserDefaults.standard
        let lastLanguage = defaults.string(forKey: lastSeenLanguageKey)
        let language = Bundle.main.preferredLocalizations.first
        if let language, language != lastLanguage {
            defaults.set(language, forKey: lastSeenLanguageKey)
        }
        guard
            let reason = WidgetReloadPlanner.launchReason(
                versionChanged: versionChanged, lastLanguage: lastLanguage, language: language)
        else { return }
        var ended = false
        if let processes = extensionProcesses() {
            // Another user's copy can't be signalled anyway.
            for pid in processes where kill(pid, SIGTERM) == 0 { ended = true }
        } else {
            Diagnostics.widget.error("Listing the processes failed; the previous widget extension may still run")
        }
        if ended {
            Diagnostics.widget.notice("Ended the previous widget extension: \(reason.rawValue, privacy: .public)")
        }
        guard ended || reason.reloadsAnyway else { return }
        // On the main actor, like the rest of the app.
        Task {
            try? await Task.sleep(for: .seconds(1))
            WidgetCenter.shared.reloadAllTimelines()
            switch reason {
            case .update:
                Diagnostics.event("widget.reload", trigger: "update")
                Diagnostics.widget.notice("Reloading the widget after an update")
            case .language:
                Diagnostics.event("widget.reload", trigger: "language")
                Diagnostics.widget.notice("Reloading the widgets after a language change")
            }
        }
    }

    /// Ends the running widget extension right before an update swaps the app. At the version
    /// change WidgetKit fetches the widget descriptors again within milliseconds, and an
    /// extension of the previous version still running answers with the previous descriptor,
    /// which WidgetKit then keeps: when the update changes the descriptor, every placed widget
    /// greys out. ``endPreviousExtension(versionChanged:)`` runs only at the new version's
    /// launch, too late.
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

    /// Demo Mode overrides one monitor or both; its readings never reach the widgets.
    private var isDemo: Bool {
        monitor.isOverridden || accessories.isOverridden
    }

    private func evaluateBattery() async {
        guard !isDemo, let snapshot = monitor.snapshot, let reason = planner.battery(snapshot, at: .now),
            await isPlaced(.battery)
        else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKindID.battery.rawValue)
        // The Battery kind keeps 0.6.x's trigger, so its counts compare with earlier versions'.
        Diagnostics.event("widget.reload", trigger: "policy")
        // One line per reload, so `log show` counts a day's reloads against WidgetKit's budget.
        let percent = snapshot.chargePercent.map { String(Int($0.rounded())) } ?? "-"
        Diagnostics.widget.notice(
            "Reloading the widget: \(snapshot.chargeState.rawValue, privacy: .public), \(percent, privacy: .public)%, \(reason.rawValue, privacy: .public)"
        )
    }

    private func evaluateAccessories() async {
        let list = accessories.accessories
        guard !isDemo, let reason = planner.accessories(list, at: .now), await isPlaced(.accessories) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKindID.accessories.rawValue)
        Diagnostics.event("widget.reload", trigger: "policy.accessories")
        Diagnostics.widget.notice(
            "Reloading the Accessories widget: \(list.count, privacy: .public) accessories, \(reason.rawValue, privacy: .public)"
        )
    }

    /// Whether `kind` is placed, asking WidgetKit first when the answer in memory can't tell
    /// (``WidgetPlacements``). Only at a reload moment, so it adds no wake-up. Each answer logs
    /// its count per kind; a failure counts as every kind placed.
    private func isPlaced(_ kind: WidgetKindID) async -> Bool {
        if placements.needsAnswer(toReload: kind, at: .now) {
            do {
                let kinds = try await PlacedWidgets.kinds()
                placements.record(answer: kinds, at: .now)
                let counts = WidgetPlacements.counts(in: kinds)
                Diagnostics.widget.notice(
                    "Placed widgets: \(kinds.count, privacy: .public) in all, \(counts[.battery] ?? 0, privacy: .public) Battery, \(counts[.accessories] ?? 0, privacy: .public) Accessories"
                )
            } catch {
                placements.recordFailure(at: .now)
                let error = error as NSError
                Diagnostics.widget.error(
                    "Asking WidgetKit for the placed widgets failed (\(error.domain, privacy: .public) \(error.code)); every kind counts as placed: \(error.localizedDescription)"
                )
            }
        }
        return placements.isPlaced(kind)
    }
}

/// WidgetKit's list of the placed widgets, as their kind strings. Nonisolated: `WidgetCenter`
/// declares no `Sendable` conformance, so it is asked off the main actor, and only the strings
/// come back.
private nonisolated enum PlacedWidgets {
    @concurrent static func kinds() async throws -> [String] {
        try await WidgetCenter.shared.currentConfigurations().map(\.kind)
    }
}
#endif

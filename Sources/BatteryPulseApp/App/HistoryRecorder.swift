#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import Foundation
import Observation

/// Where the app keeps its battery history.
enum AppHistory {
    static let store = HistoryStore(
        directory: HistoryStore.defaultDirectory(bundleIdentifier: Bundle.main.bundleIdentifier))
}

/// Writes a history sample about once a minute while BatteryPulse runs, right away when the
/// battery changes state, and the day's battery condition. The first sample after launch and
/// after the Mac wakes carries that event, so the chart can tell sleep from the app not
/// running. Skipped while recording is off or Demo Mode shows simulated data.
@MainActor
final class HistoryRecorder {
    private let monitor: BatteryMonitor
    private let store: HistoryStore
    private var task: Task<Void, Never>?
    private var pendingEvent: HistoryEvent? = .launch
    private var wakeObserver: (any NSObjectProtocol)?

    init(monitor: BatteryMonitor, store: HistoryStore = AppHistory.store) {
        self.monitor = monitor
        self.store = store
    }

    func start() {
        guard task == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pendingEvent = .wake
                Task { await self?.recordNow(refreshing: true) }
            }
        }
        observe()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.recordNow(refreshing: true)
                // The tolerance lets macOS coalesce this wake-up with others.
                try? await Task.sleep(for: .seconds(HistoryPolicy.interval), tolerance: .seconds(15))
            }
        }
    }

    /// Plugging in, unplugging and state changes arrive as new snapshots; ``HistoryPolicy``
    /// decides whether they add a sample.
    private func observe() {
        withObservationTracking {
            _ = monitor.snapshot
        } onChange: { [weak self] in
            Task { @MainActor in
                await self?.recordNow(refreshing: false)
                self?.observe()
            }
        }
    }

    private func recordNow(refreshing: Bool) async {
        guard AppSettings.recordsHistory, !monitor.isOverridden else { return }
        // Values like power change without a system notification, so the timer reads them fresh.
        if refreshing { monitor.refresh() }
        guard let snapshot = monitor.snapshot else { return }
        let now = Date()
        let event = pendingEvent
        let recorded = (try? await store.record(HistorySample(snapshot, at: now, event: event))) ?? false
        if recorded, event != nil, pendingEvent == event { pendingEvent = nil }
        try? await store.record(HistoryDay(snapshot, day: HistoryDay.key(for: now)), at: now)
    }
}
#endif

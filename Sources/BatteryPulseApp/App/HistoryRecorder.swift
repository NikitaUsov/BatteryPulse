#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation

/// Where the app keeps its battery history.
enum AppHistory {
    static let store = HistoryStore(
        directory: HistoryStore.defaultDirectory(bundleIdentifier: Bundle.main.bundleIdentifier))
}

/// Writes a history sample about once a minute while BatteryPulse runs, and the day's battery
/// condition. Skipped while recording is off or Demo Mode shows simulated data.
@MainActor
final class HistoryRecorder {
    private let monitor: BatteryMonitor
    private let store: HistoryStore
    private var task: Task<Void, Never>?

    init(monitor: BatteryMonitor, store: HistoryStore = AppHistory.store) {
        self.monitor = monitor
        self.store = store
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.recordNow()
                // The tolerance lets macOS coalesce this wake-up with others.
                try? await Task.sleep(for: .seconds(HistoryPolicy.interval), tolerance: .seconds(15))
            }
        }
    }

    private func recordNow() async {
        guard AppSettings.recordsHistory, !monitor.isOverridden else { return }
        // Values like power change without a system notification, so read them fresh.
        monitor.refresh()
        guard let snapshot = monitor.snapshot else { return }
        let now = Date()
        _ = try? await store.record(HistorySample(snapshot, at: now))
        try? await store.record(HistoryDay(snapshot, day: HistoryDay.key(for: now)))
    }
}
#endif

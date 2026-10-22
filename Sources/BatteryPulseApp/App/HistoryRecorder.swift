#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import Foundation
import Observation
import os

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
    private var observation: Task<Void, Never>?
    private var pendingEvent: HistoryEvent? = .launch
    private var wakeObserver: (any NSObjectProtocol)?

    /// A read this recent serves the minute tick and the sample after a wake as it is: with power
    /// in the menu bar, the monitor reads every 10 s anyway.
    static let freshReadAge: Duration = .seconds(20)

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
        // Plugging in, unplugging and state changes arrive as new snapshots; ``HistoryPolicy``
        // decides whether they add a sample. The snapshot at the start is no change: the first
        // tick below records the launch.
        observation = Task(name: "HistoryRecorder.observation") { [weak self, monitor] in
            for await _ in Observations({ monitor.snapshot }).dropFirst() {
                guard let self else { return }
                await self.recordNow(refreshing: false)
            }
        }
        task = Task(name: "HistoryRecorder.tick") { [weak self] in
            while !Task.isCancelled {
                await self?.recordNow(refreshing: true)
                // The tolerance lets macOS coalesce this wake-up with others.
                try? await Task.sleep(for: .seconds(HistoryPolicy.interval), tolerance: .seconds(15))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        observation?.cancel()
        observation = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    private func recordNow(refreshing: Bool) async {
        guard AppSettings.recordsHistory, !monitor.isOverridden else { return }
        // Values like power change without a system notification, so the timer reads them fresh,
        // unless a read just did. The first tick reuses the monitor's read at launch.
        if refreshing, !monitor.hasRead(within: Self.freshReadAge) { monitor.refresh(trigger: .history) }
        guard let snapshot = monitor.snapshot else { return }
        let interval = Diagnostics.begin("history.record")
        defer { interval.end() }
        let now = Date()
        let event = pendingEvent
        let recorded: Bool
        do {
            recorded = try await store.record(HistorySample(snapshot, at: now, event: event))
        } catch {
            recorded = false
            Self.logWriteFailure("a sample", error)
        }
        if recorded, event != nil, pendingEvent == event { pendingEvent = nil }
        do {
            try await store.record(HistoryDay(snapshot, day: HistoryDay.key(for: now)), at: now)
        } catch {
            Self.logWriteFailure("the day's summary", error)
        }
    }

    /// A failed write leaves a gap in the charts, so it is logged. `what` is static text; the
    /// error's domain and code are public, its description, which can name a path, is not.
    static func logWriteFailure(_ what: String, _ error: any Error) {
        let error = error as NSError
        Diagnostics.history.error(
            "Writing \(what, privacy: .public) failed (\(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
        )
    }
}
#endif

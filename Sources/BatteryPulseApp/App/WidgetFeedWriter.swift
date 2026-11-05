#if os(macOS)
import BatteryCore
import BatteryKit
import BatterySource
import Foundation
import Observation
import os

/// Where the app writes the widget's feed: the folder the widget's entitlement names, below the
/// real home, whatever this build's bundle identifier.
enum AppWidgetFeed {
    static let store = WidgetFeedStore(
        directory: WidgetFeedStore.defaultDirectory(home: FileManager.default.homeDirectoryForCurrentUser))
}

/// Writes the widget's feed (``WidgetFeed``), the small copy of the history and the remembered
/// devices that the sandboxed widget can't read itself, at moments that already happen: no timer
/// or task of its own wakes it.
///
/// - **Routine:** at the history recorder's minute tick, which runs whether or not recording is on,
///   once per 15-minute step, changed or not, so `writtenAt` keeps saying that BatteryPulse runs.
/// - **At once:** Clear History and the recording toggle (Settings → Advanced calls it), a device
///   read, forgotten or reads turned on or off, a plug change and Demo Mode's end
///   (``WidgetRefresher`` follows them).
/// - **Never** in Demo Mode, whose readings never reach the widgets.
///
/// The sections follow the placed widgets (``WidgetPlacements``), asked of WidgetKit at a write
/// moment only. One write runs at a time; the requests meanwhile make one follow-on write.
/// Observable only to be in the Settings pane's environment: nothing of it is observed.
@Observable
final class WidgetFeedWriter {
    private let monitor: BatteryMonitor
    private let history: HistoryStore
    private let store: WidgetFeedStore
    @ObservationIgnored private var schedule = WidgetFeed.StepSchedule()
    @ObservationIgnored private var placements = WidgetPlacements()
    /// The placed widgets of the last answer, as counted per kind, to log a change only.
    @ObservationIgnored private var answeredCounts: [WidgetKindID: Int]?
    @ObservationIgnored private var writing: Task<Void, Never>?
    /// What the requests made while a write ran ask for after it.
    @ObservationIgnored private var queued: (reason: WidgetFeed.WriteReason, unchanged: Bool)?

    init(
        monitor: BatteryMonitor, history: HistoryStore = AppHistory.store, store: WidgetFeedStore = AppWidgetFeed.store
    ) {
        self.monitor = monitor
        self.history = history
        self.store = store
    }

    /// The history recorder's minute tick: the routine write, at the first tick of each step.
    func tick(at date: Date = .now) {
        guard schedule.isDue(at: date) else { return }
        write(.step)
    }

    /// Writes the feed now, or right after the write that is running.
    func write(_ reason: WidgetFeed.WriteReason) {
        let unchanged = (queued?.unchanged ?? false) || reason.writesUnchanged
        // An immediate reason labels the follow-on write over a routine one: it logs.
        let label = queued.map { $0.reason == .step ? reason : $0.reason } ?? reason
        queued = (label, unchanged)
        guard writing == nil else { return }
        writing = Task(name: "WidgetFeedWriter.write") { [weak self] in
            await self?.writeQueued()
        }
    }

    /// Runs the queued writes one after another until none is left.
    private func writeQueued() async {
        while let next = queued.take() {
            await writeOnce(next.reason, unchanged: next.unchanged)
        }
        writing = nil
    }

    private func writeOnce(_ reason: WidgetFeed.WriteReason, unchanged: Bool) async {
        guard !monitor.isOverridden else { return }
        let interval = Diagnostics.begin("widget.feed.write", trigger: reason.signpostName)
        defer { interval.end() }
        // Taken before any wait, while Demo Mode is known to be off.
        let snapshot = monitor.snapshot
        let recordsHistory = AppSettings.recordsHistory
        let readsDevices = AppSettings.readsDevices
        await askForPlacementsIfNeeded(recordsHistory: recordsHistory, readsDevices: readsDevices)
        let sections = WidgetFeed.sections(
            recordsHistory: recordsHistory, readsDevices: readsDevices, placements: placements)
        // The devices and their model names as the app shows them, on the main actor.
        let devices = sections.contains(.devices) && readsDevices ? AppDevices.monitor.remembered : []
        var modelNames: [String: String] = [:]
        for productType in Set(devices.compactMap(\.productType)) {
            modelNames[productType] = IDeviceModelName.name(productType: productType)
        }
        let now = Date.now
        let source = WidgetFeed.Source(
            now: now, languages: Bundle.main.preferredLocalizations, recordsHistory: recordsHistory,
            readsDevices: readsDevices, sections: sections,
            current: snapshot.map { HistorySample($0, at: now) },
            devices: devices, modelNames: modelNames)
        guard let feed = await FeedBuild.make(source, history: history),
            // The placements and the build ran off the main actor: Demo Mode may have started
            // meanwhile.
            !monitor.isOverridden
        else { return }
        do {
            let outcome = try await FeedBuild.write(feed, to: store, unchanged: unchanged)
            Self.log(outcome, of: feed, reason: reason)
        } catch {
            // The widgets keep the previous feed and, two hours after it, say so. The error's
            // domain and code are public, its description, which can name a path, is not.
            let error = error as NSError
            Diagnostics.widget.error(
                "Writing the widget feed failed (\(reason.rawValue, privacy: .public); \(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
            )
        }
    }

    /// An immediate write logs its bytes and section counts, so `log show` finds it; the routine
    /// one, 96 a day, only its signpost's debug line.
    private static func log(_ outcome: WidgetFeedStore.Outcome, of feed: WidgetFeed, reason: WidgetFeed.WriteReason) {
        switch outcome {
        case .written(let bytes) where !reason.writesUnchanged:
            let steps = feed.day?.percent.count(where: { $0 != nil }) ?? 0
            let days = feed.daily?.cycleCount.count ?? 0
            let devices = feed.devices?.count ?? 0
            Diagnostics.widget.notice(
                "Wrote the widget feed (\(reason.rawValue, privacy: .public)): \(bytes, privacy: .public) bytes, \(steps, privacy: .public) steps of the day, \(days, privacy: .public) days, \(devices, privacy: .public) devices"
            )
        case .written:
            break
        case .unchanged:
            Diagnostics.widget.debug("The widget feed is unchanged (\(reason.rawValue, privacy: .public))")
        }
    }

    /// Asks WidgetKit for the placed widgets when the answer in memory can't tell whether a
    /// section is shown (``WidgetFeed/needsPlacementAnswer(recordsHistory:readsDevices:placements:at:readers:)``).
    /// A failure counts as every kind placed. With nothing placed that is every routine write, so
    /// an answer logs at notice only when its counts change.
    private func askForPlacementsIfNeeded(recordsHistory: Bool, readsDevices: Bool) async {
        guard
            WidgetFeed.needsPlacementAnswer(
                recordsHistory: recordsHistory, readsDevices: readsDevices, placements: placements, at: .now)
        else { return }
        do {
            let kinds = try await PlacedWidgets.kinds()
            placements.record(answer: kinds, at: .now)
            let counts = WidgetPlacements.counts(in: kinds)
            let changed = counts != answeredCounts
            answeredCounts = counts
            let level: OSLogType = changed ? .default : .debug
            Diagnostics.widget.log(
                level: level,
                "Placed widgets, for the widget feed: \(kinds.count, privacy: .public) in all, \(counts[.battery] ?? 0, privacy: .public) Battery, \(counts[.accessories] ?? 0, privacy: .public) Accessories"
            )
        } catch {
            placements.recordFailure(at: .now)
            answeredCounts = nil
            let error = error as NSError
            Diagnostics.widget.error(
                "Asking WidgetKit for the placed widgets failed (\(error.domain, privacy: .public) \(error.code)); the widget feed counts every kind as placed: \(error.localizedDescription)"
            )
        }
    }
}

/// The feed's build and write, off the main actor: the history's reads, the builder and the file.
private nonisolated enum FeedBuild {
    /// Writes `feed` through `store`, which blocks on the file system.
    @concurrent
    static func write(_ feed: WidgetFeed, to store: WidgetFeedStore, unchanged: Bool) async throws
        -> WidgetFeedStore.Outcome
    {
        try store.write(feed, unchanged: unchanged)
    }

    /// Reads what of the history `source` includes from `store`, then builds the feed; `nil` in
    /// Demo Mode, or when the history can't be read, so the previous feed stays rather than one
    /// that lost the history.
    @concurrent
    static func make(_ source: WidgetFeed.Source, history store: HistoryStore) async -> WidgetFeed? {
        var source = source
        if source.includesHistory {
            do {
                source.samples = try await store.samples(from: WidgetFeed.historyStart(at: source.now))
                source.days = try await store.dailySummaries()
            } catch {
                // The error's domain and code are public, its description, which can name a
                // path, is not.
                let error = error as NSError
                Diagnostics.history.error(
                    "Reading the history for the widget feed failed (\(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
                )
                return nil
            }
        }
        return WidgetFeed.build(source)
    }
}
#endif

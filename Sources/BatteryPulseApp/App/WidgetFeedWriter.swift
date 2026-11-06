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
///   (``WidgetRefresher`` follows them), and a launch in another language, before the widgets
///   reload (``writeAndWait(_:)``): they take BatteryPulse's language from the feed.
/// - **Never** in Demo Mode, whose readings never reach the widgets, but for what the user removes
///   meanwhile: Clear History, recording off, device reads off and Forget take their part out of
///   the feed last written at once, from the real settings and devices, and add nothing
///   (``WidgetFeed/removing(_:)``); before the first write since launch, the file goes whole.
///
/// The sections follow the placed widgets (``WidgetPlacements``), asked of WidgetKit at a write
/// moment only. One write runs at a time; the requests meanwhile make one follow-on write. A write
/// that shows the widgets something their own timelines would show only later counts in
/// ``changesWritten``, the one property anything observes: what the user removed, once the file
/// is without it, and what a write brought (``WidgetFeed/WriteEffect``), a feed in place of one
/// they couldn't use or that had aged, or a section added. ``WidgetRefresher`` then reloads the
/// kinds that show it (``takeChanges()``).
/// Observable for that, and to be in the Settings pane's environment.
@Observable
final class WidgetFeedWriter {
    private let monitor: BatteryMonitor
    private let history: HistoryStore
    private let store: WidgetFeedStore
    @ObservationIgnored private var schedule = WidgetFeed.StepSchedule()
    @ObservationIgnored private var placements = WidgetPlacements()
    /// The placed widgets of the last answer, as counted per kind, to log a change only.
    @ObservationIgnored private var answeredCounts: [WidgetKindID: Int]?
    /// The last question failed: a failure that repeats at every routine write logs at error once.
    @ObservationIgnored private var lastAnswerFailed = false
    /// The last read of the history for the feed failed: as the question's, a failure that repeats
    /// at every routine write logs at error once, then at debug until a read succeeds.
    @ObservationIgnored private var lastHistoryReadFailed = false
    @ObservationIgnored private var writing: Task<Void, Never>?
    /// What the requests made while a write ran ask for after it.
    @ObservationIgnored private var queued: (reason: WidgetFeed.WriteReason, unchanged: Bool)?
    /// Clear History ran since the last write that accounted for it: an event, not a setting, so a
    /// folded request can't lose it, and a failed write leaves it for the next.
    @ObservationIgnored private var historyCleared = false
    /// The sections the queued requests take out, for the write that serves them.
    @ObservationIgnored private var queuedRemovals: Set<WidgetFeed.Section> = []
    /// The sections the removals written since the refresher last asked took out.
    @ObservationIgnored private var removedSections: Set<WidgetFeed.Section> = []
    /// What the writes since the refresher last asked brought the widgets.
    @ObservationIgnored private var writtenEffect = WidgetFeed.WriteEffect.nothing
    /// How many writes showed the widgets something they see only after a reload: a removal, each
    /// leaving the file without it, whether it took it out or found it out already, or a write's
    /// effect.
    private(set) var changesWritten = 0

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

    /// Writes the feed now, or right after the write that is running. `removed` are the sections
    /// it takes out besides what `reason` says (``WidgetFeed/WriteReason/removes(recordsHistory:)``):
    /// the devices for reads off and Forget.
    func write(_ reason: WidgetFeed.WriteReason, removing removed: Set<WidgetFeed.Section> = []) {
        if reason == .historyCleared { historyCleared = true }
        queuedRemovals.formUnion(removed.union(reason.removes(recordsHistory: AppSettings.recordsHistory)))
        let unchanged = (queued?.unchanged ?? false) || reason.writesUnchanged
        // An immediate reason labels the follow-on write over a routine one: it logs.
        let label = queued.map { $0.reason == .step ? reason : $0.reason } ?? reason
        queued = (label, unchanged)
        guard writing == nil else { return }
        writing = Task(name: "WidgetFeedWriter.write") { [weak self] in
            await self?.writeQueued()
        }
    }

    /// Writes the feed, and returns once that write and any it was folded with are done, written
    /// or not: a launch in another language reloads the widgets only then (``WidgetRefresher``).
    func writeAndWait(_ reason: WidgetFeed.WriteReason, removing removed: Set<WidgetFeed.Section> = []) async {
        write(reason, removing: removed)
        await writing?.value
    }

    /// What the writes since the last call showed the widgets: the sections the removals took
    /// out, and what the full writes brought; for the kinds that show them to reload.
    func takeChanges() -> (removed: Set<WidgetFeed.Section>, effect: WidgetFeed.WriteEffect) {
        defer {
            removedSections = []
            writtenEffect = .nothing
        }
        return (removedSections, writtenEffect)
    }

    /// Runs the queued writes one after another until none is left. A write that didn't fail
    /// counts its removals as written even when the file was unchanged: another write may have
    /// taken them out first, one that read the history or the devices after the user's change (a
    /// routine write between Clear History and its request, or one running when Forget came), and
    /// no widget reloaded for that one. A failed write leaves them for the next.
    private func writeQueued() async {
        while let next = queued.take() {
            let removals = queuedRemovals
            queuedRemovals = []
            let result = await writeOnce(next.reason, unchanged: next.unchanged, removing: removals)
            switch result {
            case .failed:
                queuedRemovals.formUnion(removals)
            case .changed(let effect):
                record(removals, effect)
            case .unchanged:
                record(removals, .nothing)
            }
        }
        writing = nil
    }

    /// Keeps what a write showed the widgets for ``takeChanges()``, and counts it once.
    private func record(_ removals: Set<WidgetFeed.Section>, _ effect: WidgetFeed.WriteEffect) {
        guard !removals.isEmpty || effect != .nothing else { return }
        removedSections.formUnion(removals)
        writtenEffect.formUnion(effect)
        changesWritten += 1
    }

    /// What a write did to the file, and, when it wrote a feed, what that showed the widgets.
    private enum WriteResult {
        case changed(WidgetFeed.WriteEffect)
        case unchanged, failed
    }

    /// Writes the feed for `reason`. `removals` are the sections the requests it serves take out:
    /// a write that can't build a feed, in Demo Mode or with a history it can't read, still takes
    /// them out of the feed last written, whichever reason the requests were folded under.
    private func writeOnce(
        _ reason: WidgetFeed.WriteReason, unchanged: Bool, removing removals: Set<WidgetFeed.Section>
    ) async -> WriteResult {
        let clearing = historyCleared
        historyCleared = false
        guard !monitor.isOverridden else {
            return await removeInDemoMode(reason, historyCleared: clearing, removing: removals)
        }
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
        let modelNames = Self.modelNames(of: devices)
        let now = Date.now
        let source = WidgetFeed.Source(
            now: now, languages: Bundle.main.preferredLocalizations, recordsHistory: recordsHistory,
            readsDevices: readsDevices, sections: sections,
            current: snapshot.map { HistorySample($0, at: now) },
            devices: devices, modelNames: modelNames)
        let built: WidgetFeed?
        do {
            built = try await FeedBuild.make(source, history: history)
            if source.includesHistory { lastHistoryReadFailed = false }
        } catch {
            // The error's domain and code are public, its description, which can name a path, is
            // not.
            let level: OSLogType = lastHistoryReadFailed ? .debug : .error
            lastHistoryReadFailed = true
            let error = error as NSError
            Diagnostics.history.log(
                level: level,
                "Reading the history for the widget feed failed (\(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
            )
            built = nil
        }
        guard let feed = built else {
            // The history couldn't be read, so the previous feed stays; a clear, a device
            // forgotten or reads turned off still leave it.
            return clearing || !removals.isEmpty ? await removeOnly(reason, historyCleared: clearing) : .failed
        }
        // The placements and the build ran off the main actor: Demo Mode may have started
        // meanwhile.
        guard !monitor.isOverridden else {
            return await removeInDemoMode(reason, historyCleared: clearing, removing: removals)
        }
        do {
            let (outcome, effect) = try await FeedBuild.write(feed, to: store, unchanged: unchanged)
            Self.log(outcome, of: feed, reason: reason)
            return outcome == .unchanged ? .unchanged : .changed(effect)
        } catch {
            if clearing { historyCleared = true }
            // The widgets keep the previous feed and, two hours after it, say so. The error's
            // domain and code are public, its description, which can name a path, is not.
            let error = error as NSError
            Diagnostics.widget.error(
                "Writing the widget feed failed (\(reason.rawValue, privacy: .public); \(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
            )
            return .failed
        }
    }

    /// The model names of `devices`' product types, as the app shows them.
    static func modelNames(of devices: [RememberedDevice]) -> [String: String] {
        var names: [String: String] = [:]
        for productType in Set(devices.compactMap(\.productType)) {
            names[productType] = IDeviceModelName.name(productType: productType)
        }
        return names
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
        case .written, .removed:
            break
        case .unchanged:
            Diagnostics.widget.debug("The widget feed is unchanged (\(reason.rawValue, privacy: .public))")
        }
    }

    /// Demo Mode lets through only a removal the user made meanwhile: one of the reasons a removal
    /// arrives with, a clear that a write hasn't accounted for yet, or a removal a request folded
    /// into this write asked for.
    private func removeInDemoMode(
        _ reason: WidgetFeed.WriteReason, historyCleared: Bool, removing removals: Set<WidgetFeed.Section>
    ) async -> WriteResult {
        guard reason.removesInDemoMode || historyCleared || !removals.isEmpty else { return .unchanged }
        return await removeOnly(reason, historyCleared: historyCleared)
    }

    /// Takes out of the feed last written what the user removed, from the real settings and the
    /// real remembered devices, never the demo's, and adds, updates or moves nothing
    /// (``WidgetFeed/removing(_:)``). Logs at notice when it took something out, so `log show`
    /// finds it.
    private func removeOnly(_ reason: WidgetFeed.WriteReason, historyCleared: Bool) async -> WriteResult {
        let interval = Diagnostics.begin("widget.feed.write", trigger: reason.signpostName)
        defer { interval.end() }
        let removal = WidgetFeed.Removal(
            historyCleared: historyCleared, recordsHistory: AppSettings.recordsHistory,
            readsDevices: AppSettings.readsDevices, remembered: Set(AppDevices.monitor.remembered.map(\.id)))
        do {
            switch try await FeedBuild.rewrite(store, with: removal) {
            case .written(let bytes):
                Diagnostics.widget.notice(
                    "Took a removal out of the widget feed (\(reason.rawValue, privacy: .public)), nothing added: \(bytes, privacy: .public) bytes"
                )
                return .changed(.nothing)
            case .removed:
                Diagnostics.widget.notice(
                    "Removed the widget feed for a removal (\(reason.rawValue, privacy: .public)): none was written since launch"
                )
                return .changed(.nothing)
            case .unchanged, nil:
                Diagnostics.widget.debug(
                    "Nothing to take out of the widget feed (\(reason.rawValue, privacy: .public))")
                return .unchanged
            }
        } catch {
            if historyCleared { self.historyCleared = true }
            // The error's domain and code are public, its description, which can name a path, is
            // not.
            let error = error as NSError
            Diagnostics.widget.error(
                "Taking a removal out of the widget feed failed (\(reason.rawValue, privacy: .public); \(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
            )
            return .failed
        }
    }

    /// Asks WidgetKit for the placed widgets when the answer in memory can't tell whether a
    /// section is shown (``WidgetFeed/needsPlacementAnswer(recordsHistory:readsDevices:placements:at:readers:)``).
    /// A failure counts as every kind placed. With nothing placed, or WidgetKit failing, that is
    /// every routine write, so an answer logs at notice only when its counts change, and a failure
    /// at error only when the question before it didn't fail.
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
            lastAnswerFailed = false
            let level: OSLogType = changed ? .default : .debug
            Diagnostics.widget.log(
                level: level,
                "Placed widgets, for the widget feed: \(kinds.count, privacy: .public) in all, \(counts[.battery] ?? 0, privacy: .public) Battery, \(counts[.accessories] ?? 0, privacy: .public) Accessories, \(counts[.history] ?? 0, privacy: .public) History, \(counts[.devices] ?? 0, privacy: .public) iPhone & iPad"
            )
        } catch {
            placements.recordFailure(at: .now)
            answeredCounts = nil
            let level: OSLogType = lastAnswerFailed ? .debug : .error
            lastAnswerFailed = true
            let error = error as NSError
            Diagnostics.widget.log(
                level: level,
                "Asking WidgetKit for the placed widgets failed (\(error.domain, privacy: .public) \(error.code)); the widget feed counts every kind as placed: \(error.localizedDescription)"
            )
        }
    }
}

/// The feed's build and write, off the main actor: the history's reads, the builder and the file.
private nonisolated enum FeedBuild {
    /// Takes `removal` out of the feed `store` last wrote, or removes the file a previous launch
    /// left before its first write, which blocks on the file system; `nil` without a file.
    @concurrent
    static func rewrite(_ store: WidgetFeedStore, with removal: WidgetFeed.Removal) async throws
        -> WidgetFeedStore.Outcome?
    {
        try store.rewrite { $0.removing(removal) }
    }

    /// Writes `feed` through `store`, which blocks on the file system, and says what the write
    /// showed the widgets (``WidgetFeedStore/writeReporting(_:unchanged:)``).
    @concurrent
    static func write(_ feed: WidgetFeed, to store: WidgetFeedStore, unchanged: Bool) async throws
        -> (outcome: WidgetFeedStore.Outcome, effect: WidgetFeed.WriteEffect)
    {
        try store.writeReporting(feed, unchanged: unchanged)
    }

    /// Reads what of the history `source` includes from `store`, then builds the feed; `nil` in
    /// Demo Mode. Throws when the history can't be read, so the previous feed stays rather than
    /// one that lost the history, and the writer logs it.
    @concurrent
    static func make(_ source: WidgetFeed.Source, history store: HistoryStore) async throws -> WidgetFeed? {
        var source = source
        if source.includesHistory {
            source.samples = try await store.samples(from: WidgetFeed.historyStart(at: source.now))
            source.days = try await store.dailySummaries()
        }
        return WidgetFeed.build(source)
    }
}
#endif

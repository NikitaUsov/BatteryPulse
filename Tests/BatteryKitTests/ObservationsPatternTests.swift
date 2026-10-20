import BatteryCore
import Foundation
import Observation
import Testing

@testable import BatteryKit

/// The app's observers (`HistoryRecorder`, `BatteryNotifier` and `WidgetRefresher`, macOS only)
/// each run one named task over `Observations { … }.dropFirst()`, cancelled in `stop()`. These
/// pin what they rely on, with the monitor they observe: nothing for the value at the start, so
/// a launch adds no history sample, notification or widget reload; one value per change; and
/// the loop ends with its task.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ObservationsPatternTests {
    /// The charge of every snapshot the observer saw, in order.
    @MainActor
    final class Seen {
        var percents: [Double?] = []
    }

    let provider = MockBatteryProvider(next: Self.reading(percent: 80))
    let monitor: BatteryMonitor
    let seen = Seen()

    init() {
        monitor = BatteryMonitor(provider: provider)
        // The value the observer starts with.
        monitor.refresh()
    }

    private static func reading(percent: Double) -> BatteryReading {
        BatteryReading(
            snapshot: BatterySnapshot(timestamp: Date(timeIntervalSince1970: 1), chargePercent: percent))
    }

    /// The app's pattern, appending to ``seen``. Returns once the observer waits for a change: the
    /// first value (dropped) is the one at that moment, so a change made before would be lost.
    private func startObserver() async -> Task<Void, Never> {
        let task = Task(name: "ObservationsPatternTests.observer") { [monitor, seen] in
            for await snapshot in Observations({ monitor.snapshot }).dropFirst() {
                seen.percents.append(snapshot?.chargePercent)
            }
        }
        await wait(for: .milliseconds(50))
        return task
    }

    private func change(to percent: Double) {
        provider.next = Self.reading(percent: percent)
        monitor.refresh()
    }

    /// Lets the observer run until it saw `count` values; the bound only ends a broken test.
    private func settle(untilSeen count: Int) async {
        let deadline = ContinuousClock.now + .seconds(10)
        while seen.percents.count < count, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    private func wait(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }

    @Test func yieldsOneValuePerChangeAndNoneAtTheStart() async {
        let observer = await startObserver()
        defer { observer.cancel() }
        #expect(seen.percents.isEmpty)
        change(to: 79)
        await settle(untilSeen: 1)
        // The same reading again: the monitor keeps its snapshot, so nothing changed.
        monitor.refresh()
        change(to: 78)
        await settle(untilSeen: 2)
        await wait(for: .milliseconds(50))
        #expect(seen.percents == [79, 78])
    }

    /// Changes in one turn of the main actor arrive as one value, the last.
    @Test func changesInOneTurnArriveOnce() async {
        let observer = await startObserver()
        defer { observer.cancel() }
        change(to: 79)
        change(to: 78)
        await settle(untilSeen: 1)
        change(to: 77)
        await settle(untilSeen: 2)
        await wait(for: .milliseconds(50))
        #expect(seen.percents == [78, 77])
    }

    @Test func cancellingTheTaskEndsTheLoop() async {
        let observer = await startObserver()
        observer.cancel()
        await observer.value
        change(to: 79)
        await wait(for: .milliseconds(50))
        #expect(seen.percents.isEmpty)
    }
}

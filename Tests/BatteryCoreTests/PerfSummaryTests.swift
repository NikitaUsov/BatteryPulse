import BatteryCore
import Testing

@Suite struct PerfSummaryTests {
    private typealias Key = PerfSummary.Key

    @Test func countsSumsAndKeepsTheLongestPerNameAndTrigger() {
        let summary = PerfSummary()
        summary.recordInterval("read", trigger: "full", duration: .milliseconds(12))
        summary.recordInterval("read", trigger: "full", duration: .milliseconds(30))
        summary.recordInterval("read", trigger: "cached", duration: .microseconds(400))
        summary.recordInterval("history.load", trigger: "-", duration: .milliseconds(5))
        summary.recordEvent("widget.reload", trigger: "policy")
        summary.recordEvent("widget.reload", trigger: "policy")
        summary.recordEvent("menuBarReady", trigger: "-")
        let snapshot = summary.snapshot()
        #expect(
            snapshot.intervals == [
                Key(name: "read", trigger: "full"): .init(
                    count: 2, total: .milliseconds(42), longest: .milliseconds(30)),
                Key(name: "read", trigger: "cached"): .init(
                    count: 1, total: .microseconds(400), longest: .microseconds(400)),
                Key(name: "history.load", trigger: "-"): .init(
                    count: 1, total: .milliseconds(5), longest: .milliseconds(5)),
            ])
        #expect(
            snapshot.events == [
                Key(name: "widget.reload", trigger: "policy"): 2, Key(name: "menuBarReady", trigger: "-"): 1,
            ])
    }

    @Test func linesAreSortedIntervalsThenEvents() {
        let summary = PerfSummary()
        summary.recordEvent("widget.reload", trigger: "policy")
        summary.recordInterval("read", trigger: "live", duration: .microseconds(412))
        summary.recordInterval("history.load", trigger: "-", duration: .milliseconds(85))
        summary.recordInterval("read", trigger: "full", duration: .milliseconds(3))
        summary.recordEvent("menuBarReady", trigger: "-")
        #expect(
            summary.snapshot().lines == [
                "history.load: 1 in 85.000 ms, longest 85.000 ms",
                "read full: 1 in 3.000 ms, longest 3.000 ms",
                "read live: 1 in 0.412 ms, longest 0.412 ms",
                "menuBarReady: 1",
                "widget.reload policy: 1",
            ])
    }

    /// A clock never runs backwards, but a negative duration mustn't lower a total.
    @Test func aNegativeDurationCountsAsZero() {
        let summary = PerfSummary()
        summary.recordInterval("read", trigger: "full", duration: .milliseconds(-3))
        #expect(summary.snapshot().intervals[Key(name: "read", trigger: "full")] == .init(count: 1))
    }

    @Test func elapsedIsSinceTheSummaryWasMade() {
        let started = ContinuousClock.now
        let summary = PerfSummary(started: started)
        #expect(summary.snapshot(now: started + .seconds(3600)).elapsed == .seconds(3600))
        #expect(summary.snapshot(now: started - .seconds(1)).elapsed == .zero)
        #expect(PerfSummary().snapshot().intervals.isEmpty)
    }

    @Test func recordsFromManyTasksAtOnce() async {
        let summary = PerfSummary()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    for _ in 0..<250 {
                        summary.recordInterval("read", trigger: "live", duration: .microseconds(1))
                        summary.recordEvent("registry.missed", trigger: "notify")
                    }
                }
            }
        }
        let snapshot = summary.snapshot()
        #expect(snapshot.intervals[Key(name: "read", trigger: "live")]?.count == 2000)
        #expect(snapshot.intervals[Key(name: "read", trigger: "live")]?.total == .milliseconds(2))
        #expect(snapshot.events[Key(name: "registry.missed", trigger: "notify")] == 2000)
    }

    @Test(arguments: [
        (Duration.zero, "0.000"),
        (.nanoseconds(1_499), "0.001"),
        (.nanoseconds(1_500), "0.002"),
        (.microseconds(999_999), "999.999"),
        (.seconds(2) + .microseconds(5), "2000.005"),
        (.milliseconds(-3), "0.000"),
    ])
    func millisecondsHaveThreeDecimals(duration: Duration, text: String) {
        #expect(PerfSummary.milliseconds(duration) == text)
    }
}

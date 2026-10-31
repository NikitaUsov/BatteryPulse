import BatteryCore
import Testing

@testable import BatterySource

#if canImport(os)
import os
#endif

/// The `perf` lines are parsed by `scripts/perf-stats.swift`, so their format is fixed.
@Suite struct DiagnosticsTests {
    @Test func intervalLine() {
        #expect(
            PerfLine.interval("read", duration: .microseconds(412), trigger: PerfLine.trigger(nil))
                == "perf interval read ms=0.412 trigger=-")
        #expect(
            PerfLine.interval(
                "refresh", duration: .milliseconds(85), trigger: PerfLine.trigger(RefreshTrigger.notify.name))
                == "perf interval refresh ms=85.000 trigger=notify")
    }

    @Test func eventLine() {
        #expect(PerfLine.event("menuBarReady", trigger: PerfLine.trigger(nil)) == "perf event menuBarReady trigger=-")
        #expect(
            PerfLine.event("widget.reload", trigger: PerfLine.trigger("policy"))
                == "perf event widget.reload trigger=policy")
    }

    @Test(arguments: [
        (Duration.zero, "0.000"),
        (.nanoseconds(1_499), "0.001"),
        (.nanoseconds(1_500), "0.002"),
        (.microseconds(999_999), "999.999"),
        (.seconds(2) + .microseconds(5), "2000.005"),
        // A clock never runs backwards, but a negative duration mustn't print one.
        (.milliseconds(-3), "0.000"),
    ])
    func millisecondsHaveThreeDecimals(duration: Duration, text: String) {
        #expect(PerfLine.milliseconds(duration) == text)
    }

    @Test func triggerNames() {
        #expect(
            RefreshTrigger.allCases.map(\.name.description) == [
                "notify", "poll", "followUp", "launch", "history", "demo", "manual",
            ])
    }

    /// The `read` interval's trigger names its two decisions: the registry, and the SMC's keys.
    @Test func readScopeNames() {
        let scopes: [BatteryReadScope] = [.full, .live, .cached, .cachedSlow]
        #expect(scopes.map(\.signpostName.description) == ["full", "live", "cached", "cached.slow"])
        #expect(scopes.map(\.rereadsRegistry) == [true, true, false, false])
        #expect(scopes.map(\.readsAllSMCKeys) == [true, false, false, true])
    }

    /// Every ended interval and every event is counted in the summary, on every platform.
    @Test func signpostsFeedTheirSummary() {
        let summary = PerfSummary()
        #if canImport(os)
        let signposts = Signposts(
            subsystem: Diagnostics.subsystem, log: Logger(subsystem: Diagnostics.subsystem, category: "perf"),
            summary: summary)
        #else
        let signposts = Signposts(summary: summary)
        #endif
        #expect(signposts.measure("read", trigger: "full") { 42 } == 42)
        var interval = signposts.begin("page.switch")
        interval.trigger = "overview"
        #expect(summary.snapshot().intervals.count == 1, "an interval counts when it ends")
        interval.end()
        signposts.event("menuBarReady")
        signposts.event("widget.reload", trigger: "policy")
        let snapshot = summary.snapshot()
        typealias Key = PerfSummary.Key
        #expect(
            Set(snapshot.intervals.keys) == [
                Key(name: "page.switch", trigger: "overview"), Key(name: "read", trigger: "full"),
            ])
        #expect(snapshot.intervals.values.allSatisfy { $0.count == 1 })
        #expect(
            snapshot.events == [
                Key(name: "menuBarReady", trigger: "-"): 1, Key(name: "widget.reload", trigger: "policy"): 1,
            ])
    }

    /// `Diagnostics`, and the app's twin, which makes its `Signposts` the same way, feed the
    /// session's summary. Other tests may measure at the same time, so only the growth is checked.
    @Test func diagnosticsFeedTheSessionSummary() {
        let key = PerfSummary.Key(name: "registry.missed", trigger: RefreshTrigger.manual.name.description)
        let before = PerfSummary.session.snapshot().events[key] ?? 0
        Diagnostics.event("registry.missed", trigger: RefreshTrigger.manual.name)
        #expect((PerfSummary.session.snapshot().events[key] ?? 0) >= before + 1)
    }

    @Test func measureReturnsTheBodysValueAndRethrows() {
        struct Failure: Error {}
        #expect(Diagnostics.measure("read") { 42 } == 42)
        #expect(throws: Failure.self) { try Diagnostics.measure("read", trigger: "manual") { throw Failure() } }
        var interval = Diagnostics.begin("page.switch")
        interval.trigger = "overview"
        interval.end()
        Diagnostics.event("menuBarReady")
    }
}

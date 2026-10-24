import Testing

@testable import BatteryKit

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

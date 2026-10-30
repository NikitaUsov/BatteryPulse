import BatteryCore

#if canImport(os)
import os
#endif

/// Why `BatteryMonitor` reads the battery: the trigger of its `refresh` interval (see
/// ``Signposts``).
public enum RefreshTrigger: Sendable, CaseIterable {
    /// A power-source or system-state change notification.
    case notify
    /// A live-refresh tick, or the read that a new polling request starts with.
    case poll
    /// One of the extra reads after the adapter was plugged in or out.
    case followUp
    /// The monitor starting.
    case launch
    /// The history recorder's sample: its minute tick, or the one after the Mac wakes.
    case history
    /// Demo Mode starting, ending or changing its simulated battery.
    case demo
    /// A caller that needs a value now, such as Copy Report.
    case manual

    /// The text of the `trigger=` field.
    public var name: StaticString {
        switch self {
        case .notify: "notify"
        case .poll: "poll"
        case .followUp: "followUp"
        case .launch: "launch"
        case .history: "history"
        case .demo: "demo"
        case .manual: "manual"
        }
    }
}

/// Times named intervals and marks events, as Points of Interest signposts for Instruments and as
/// `.debug` lines in the `perf` category, which `log stream` shows without Instruments or a
/// debuggable build, and `scripts/perf-stats.swift` reads:
///
///     perf interval <name> ms=<duration, 3 decimals> trigger=<trigger or ->
///     perf event <name> trigger=<trigger or ->
///
/// The trigger is the one static detail an interval carries, such as why the battery was read
/// (``RefreshTrigger``) or which page appeared. Names and triggers are `StaticString`s, so every
/// part of a line is static text or a number and logs as public. Every ended interval and every
/// event is also counted in a `PerfSummary` (`PerfSummary.session` unless told otherwise), the
/// in-memory sums a problem report shows, since the app can't read its debug lines back. Where
/// there is no `os` module (Linux), only that summary is fed, and ``measure(_:trigger:_:)``
/// otherwise only runs its body.
public struct Signposts: Sendable {
    /// Where the intervals and events are counted.
    let summary: PerfSummary
    #if canImport(os)
    private let signposter: OSSignposter
    private let log: Logger

    /// - Parameters:
    ///   - subsystem: The subsystem of the signposts.
    ///   - log: The logger of the `perf` category, which gets the lines.
    ///   - summary: Where the intervals and events are counted.
    public init(subsystem: String, log: Logger, summary: PerfSummary = .session) {
        signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
        self.log = log
        self.summary = summary
    }
    #else
    /// - Parameter summary: Where the intervals and events are counted.
    public init(summary: PerfSummary = .session) {
        self.summary = summary
    }
    #endif

    /// An interval that ``Signposts/begin(_:trigger:)`` started and ``end()`` closes.
    public struct Interval: Sendable {
        let name: StaticString
        /// Settable until ``end()``, for a trigger that is only known at the end.
        public var trigger: StaticString?
        let signposts: Signposts
        let start: ContinuousClock.Instant
        #if canImport(os)
        let state: OSSignpostIntervalState
        #endif

        /// Ends the signpost interval, counts it in the summary and logs its `perf` line.
        public func end() {
            let duration = ContinuousClock.now - start
            let text = PerfLine.trigger(trigger)
            let label = name.description
            signposts.summary.recordInterval(label, trigger: text, duration: duration)
            #if canImport(os)
            signposts.signposter.endInterval(name, state, "\(text, privacy: .public)")
            // Built only when the line is logged: `log stream` or `log config` at the debug level.
            signposts.log.debug("\(PerfLine.interval(label, duration: duration, trigger: text), privacy: .public)")
            #endif
        }
    }

    /// Starts an interval; call ``Interval/end()`` on the result, usually in a `defer`.
    public func begin(_ name: StaticString, trigger: StaticString? = nil) -> Interval {
        let start = ContinuousClock.now
        #if canImport(os)
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        return Interval(name: name, trigger: trigger, signposts: self, start: start, state: state)
        #else
        return Interval(name: name, trigger: trigger, signposts: self, start: start)
        #endif
    }

    /// Runs `body` inside an interval.
    public func measure<T>(_ name: StaticString, trigger: StaticString? = nil, _ body: () throws -> T) rethrows -> T {
        let interval = begin(name, trigger: trigger)
        defer { interval.end() }
        return try body()
    }

    /// Marks a moment, such as a widget reload, and counts it in the summary.
    public func event(_ name: StaticString, trigger: StaticString? = nil) {
        let text = PerfLine.trigger(trigger)
        let label = name.description
        summary.recordEvent(label, trigger: text)
        #if canImport(os)
        signposter.emitEvent(name, "\(text, privacy: .public)")
        log.debug("\(PerfLine.event(label, trigger: text), privacy: .public)")
        #endif
    }
}

/// The text of the `perf` lines (see ``Signposts``).
enum PerfLine {
    static func interval(_ name: String, duration: Duration, trigger: String) -> String {
        "perf interval \(name) ms=\(milliseconds(duration)) trigger=\(trigger)"
    }

    static func event(_ name: String, trigger: String) -> String {
        "perf event \(name) trigger=\(trigger)"
    }

    /// A trigger's text, `-` for none.
    static func trigger(_ trigger: StaticString?) -> String {
        trigger?.description ?? "-"
    }

    /// Milliseconds with three decimals, rounded to the nearest microsecond: `0.412`, `85.000`,
    /// as the summary writes them.
    static func milliseconds(_ duration: Duration) -> String {
        PerfSummary.milliseconds(duration)
    }
}

/// The loggers of BatterySource and BatteryKit, one per area, and their signposts, in the app's
/// subsystem. The app has a twin for its own areas (`App/Diagnostics.swift`). Error descriptions,
/// paths, device names, serials and UDIDs never log as public.
public enum Diagnostics {
    public static let subsystem = "io.github.nikitausov.BatteryPulse"

    #if canImport(os)
    public static let monitor = Logger(subsystem: subsystem, category: "monitor")
    public static let smc = Logger(subsystem: subsystem, category: "smc")
    public static let iokit = Logger(subsystem: subsystem, category: "iokit")
    public static let device = Logger(subsystem: subsystem, category: "device")
    public static let accessory = Logger(subsystem: subsystem, category: "accessory")
    public static let update = Logger(subsystem: subsystem, category: "update")
    /// The `perf` lines of ``signposts``.
    public static let perf = Logger(subsystem: subsystem, category: "perf")
    public static let signposts = Signposts(subsystem: subsystem, log: perf)
    #else
    public static let signposts = Signposts()
    #endif

    public static func begin(_ name: StaticString, trigger: StaticString? = nil) -> Signposts.Interval {
        signposts.begin(name, trigger: trigger)
    }

    public static func measure<T>(_ name: StaticString, trigger: StaticString? = nil, _ body: () throws -> T) rethrows
        -> T
    {
        try signposts.measure(name, trigger: trigger, body)
    }

    public static func event(_ name: StaticString, trigger: StaticString? = nil) {
        signposts.event(name, trigger: trigger)
    }
}

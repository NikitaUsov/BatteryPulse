#if canImport(os)
import os
#endif

/// Why ``BatteryMonitor`` reads the battery: the trigger of its `refresh` interval (see
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
/// part of a line is static text or a number and logs as public. Where there is no `os` module
/// (Linux), nothing is recorded and ``measure(_:trigger:_:)`` only runs its body.
public struct Signposts: Sendable {
    #if canImport(os)
    private let signposter: OSSignposter
    private let log: Logger

    /// - Parameters:
    ///   - subsystem: The subsystem of the signposts.
    ///   - log: The logger of the `perf` category, which gets the lines.
    public init(subsystem: String, log: Logger) {
        signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
        self.log = log
    }
    #else
    public init() {}
    #endif

    /// An interval that ``Signposts/begin(_:trigger:)`` started and ``end()`` closes.
    public struct Interval: Sendable {
        let name: StaticString
        /// Settable until ``end()``, for a trigger that is only known at the end.
        public var trigger: StaticString?
        #if canImport(os)
        let signposts: Signposts
        let state: OSSignpostIntervalState
        let start: ContinuousClock.Instant
        #endif

        /// Ends the signpost interval and logs its `perf` line.
        public func end() {
            #if canImport(os)
            let duration = ContinuousClock.now - start
            let text = PerfLine.trigger(trigger)
            signposts.signposter.endInterval(name, state, "\(text, privacy: .public)")
            let label = name.description
            // Built only when the line is logged: `log stream` or `log config` at the debug level.
            signposts.log.debug("\(PerfLine.interval(label, duration: duration, trigger: text), privacy: .public)")
            #endif
        }
    }

    /// Starts an interval; call ``Interval/end()`` on the result, usually in a `defer`.
    public func begin(_ name: StaticString, trigger: StaticString? = nil) -> Interval {
        #if canImport(os)
        let start = ContinuousClock.now
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        return Interval(name: name, trigger: trigger, signposts: self, state: state, start: start)
        #else
        return Interval(name: name, trigger: trigger)
        #endif
    }

    /// Runs `body` inside an interval.
    public func measure<T>(_ name: StaticString, trigger: StaticString? = nil, _ body: () throws -> T) rethrows -> T {
        let interval = begin(name, trigger: trigger)
        defer { interval.end() }
        return try body()
    }

    /// Marks a moment, such as a widget reload.
    public func event(_ name: StaticString, trigger: StaticString? = nil) {
        #if canImport(os)
        let text = PerfLine.trigger(trigger)
        signposter.emitEvent(name, "\(text, privacy: .public)")
        let label = name.description
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

    /// Milliseconds with three decimals, rounded to the nearest microsecond: `0.412`, `85.000`.
    static func milliseconds(_ duration: Duration) -> String {
        let (seconds, attoseconds) = max(duration, .zero).components
        let microseconds = seconds * 1_000_000 + (attoseconds + 500_000_000_000) / 1_000_000_000_000
        let fraction = String(microseconds % 1000)
        return "\(microseconds / 1000)." + String(repeating: "0", count: 3 - fraction.count) + fraction
    }
}

/// BatteryKit's loggers, one per area, and its signposts, in the app's subsystem. The app has a
/// twin for its own areas (`App/Diagnostics.swift`). Error descriptions, paths, device names,
/// serials and UDIDs never log as public.
enum Diagnostics {
    static let subsystem = "io.github.nikitausov.BatteryPulse"

    #if canImport(os)
    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let smc = Logger(subsystem: subsystem, category: "smc")
    static let iokit = Logger(subsystem: subsystem, category: "iokit")
    static let device = Logger(subsystem: subsystem, category: "device")
    static let accessory = Logger(subsystem: subsystem, category: "accessory")
    static let update = Logger(subsystem: subsystem, category: "update")
    /// The `perf` lines of ``signposts``.
    static let perf = Logger(subsystem: subsystem, category: "perf")
    static let signposts = Signposts(subsystem: subsystem, log: perf)
    #else
    static let signposts = Signposts()
    #endif

    static func begin(_ name: StaticString, trigger: StaticString? = nil) -> Signposts.Interval {
        signposts.begin(name, trigger: trigger)
    }

    static func measure<T>(_ name: StaticString, trigger: StaticString? = nil, _ body: () throws -> T) rethrows -> T {
        try signposts.measure(name, trigger: trigger, body)
    }

    static func event(_ name: StaticString, trigger: StaticString? = nil) {
        signposts.event(name, trigger: trigger)
    }
}

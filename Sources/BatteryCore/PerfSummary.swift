import Synchronization

/// This process's `perf` lines, summed in memory: for each signpost name and trigger, how many
/// intervals ended, their total and their longest time, and how many events were marked.
///
/// Both `Diagnostics` twins feed ``session`` through BatterySource's `Signposts`, so a problem
/// report can say what this launch measured: the `perf` lines themselves are debug lines, which
/// the system doesn't keep, so the app can't read them back. Recording is a dictionary update
/// behind a `Mutex`, with no I/O; the keys are the signposts' static names and triggers, so the
/// dictionary stays small however long the app runs.
public final class PerfSummary: Sendable {
    /// What this process's signposts feed.
    public static let session = PerfSummary()

    /// A signpost name and its trigger, `-` for none, as the `perf` lines write them.
    public struct Key: Sendable, Hashable, Comparable {
        public var name: String
        public var trigger: String

        public init(name: String, trigger: String) {
            self.name = name
            self.trigger = trigger
        }

        public static func < (lhs: Key, rhs: Key) -> Bool {
            (lhs.name, lhs.trigger) < (rhs.name, rhs.trigger)
        }
    }

    /// The intervals of one key.
    public struct Totals: Sendable, Equatable {
        public var count = 0
        public var total = Duration.zero
        public var longest = Duration.zero

        public init(count: Int = 0, total: Duration = .zero, longest: Duration = .zero) {
            self.count = count
            self.total = total
            self.longest = longest
        }
    }

    /// What the summary held at one moment.
    public struct Snapshot: Sendable, Equatable {
        public var intervals: [Key: Totals]
        public var events: [Key: Int]
        /// Since the summary was made: for ``PerfSummary/session``, about since launch.
        public var elapsed: Duration

        public init(intervals: [Key: Totals] = [:], events: [Key: Int] = [:], elapsed: Duration = .zero) {
            self.intervals = intervals
            self.events = events
            self.elapsed = elapsed
        }

        /// One line per key, intervals first, each group sorted by name and trigger:
        ///
        ///     read full: 12 in 123.456 ms, longest 85.000 ms
        ///     widget.reload policy: 3
        ///
        /// The trigger is left out when there is none.
        public var lines: [String] {
            let intervalLines = intervals.sorted { $0.key < $1.key }.map { key, totals in
                "\(key.label): \(totals.count) in \(PerfSummary.milliseconds(totals.total)) ms, "
                    + "longest \(PerfSummary.milliseconds(totals.longest)) ms"
            }
            let eventLines = events.sorted { $0.key < $1.key }.map { key, count in "\(key.label): \(count)" }
            return intervalLines + eventLines
        }
    }

    private struct State {
        var intervals: [Key: Totals] = [:]
        var events: [Key: Int] = [:]
    }

    private let state = Mutex(State())
    /// When the summary was made.
    public let started: ContinuousClock.Instant

    public init(started: ContinuousClock.Instant = .now) {
        self.started = started
    }

    /// An interval named `name` ended after `duration`; a negative one counts as zero.
    public func recordInterval(_ name: String, trigger: String, duration: Duration) {
        let duration = max(duration, .zero)
        state.withLock { state in
            var totals = state.intervals[Key(name: name, trigger: trigger), default: Totals()]
            totals.count += 1
            totals.total += duration
            totals.longest = max(totals.longest, duration)
            state.intervals[Key(name: name, trigger: trigger)] = totals
        }
    }

    /// An event named `name` was marked.
    public func recordEvent(_ name: String, trigger: String) {
        state.withLock { state in
            state.events[Key(name: name, trigger: trigger), default: 0] += 1
        }
    }

    /// What the summary holds now; `now` is when it is read.
    public func snapshot(now: ContinuousClock.Instant = .now) -> Snapshot {
        let (intervals, events) = state.withLock { ($0.intervals, $0.events) }
        return Snapshot(intervals: intervals, events: events, elapsed: max(now - started, .zero))
    }

    /// Milliseconds with three decimals, rounded to the nearest microsecond: `0.412`, `85.000`.
    /// The `perf` lines write their durations the same way.
    public static func milliseconds(_ duration: Duration) -> String {
        let (seconds, attoseconds) = max(duration, .zero).components
        let microseconds = seconds * 1_000_000 + (attoseconds + 500_000_000_000) / 1_000_000_000_000
        let fraction = String(microseconds % 1000)
        return "\(microseconds / 1000)." + String(repeating: "0", count: 3 - fraction.count) + fraction
    }
}

extension PerfSummary.Key {
    /// `read full`, or `menuBarReady` without a trigger.
    var label: String {
        trigger == "-" ? name : "\(name) \(trigger)"
    }
}

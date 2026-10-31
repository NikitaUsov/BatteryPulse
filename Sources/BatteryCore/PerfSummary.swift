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
    public struct Key: Sendable, Hashable {
        public var name: String
        public var trigger: String

        public init(name: String, trigger: String) {
            self.name = name
            self.trigger = trigger
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
    public struct Snapshot: Sendable {
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
            let intervalLines = intervals.sorted { $0.key.precedes($1.key) }.map { key, totals in
                "\(key.label): \(totals.count) in \(PerfSummary.milliseconds(totals.total)) ms, "
                    + "longest \(PerfSummary.milliseconds(totals.longest)) ms"
            }
            let eventLines = events.sorted { $0.key.precedes($1.key) }.map { key, count in "\(key.label): \(count)" }
            return intervalLines + eventLines
        }
    }

    /// An interval's key or an event's: one dictionary holds both, whose code every binary that
    /// signposts carries, the widget's too.
    private struct Slot: Hashable {
        var key: Key
        var isEvent: Bool
    }

    /// An event's slot counts in `count` alone.
    private let slots = Mutex<[Slot: Totals]>([:])
    /// When the summary was made.
    public let started: ContinuousClock.Instant

    public init(started: ContinuousClock.Instant = .now) {
        self.started = started
    }

    /// An interval named `name` ended after `duration`; a negative one counts as zero.
    public func recordInterval(_ name: String, trigger: String, duration: Duration) {
        let duration = max(duration, .zero)
        let slot = Slot(key: Key(name: name, trigger: trigger), isEvent: false)
        slots.withLock { slots in
            var totals = slots[slot, default: Totals()]
            totals.count += 1
            totals.total += duration
            totals.longest = max(totals.longest, duration)
            slots[slot] = totals
        }
    }

    /// An event named `name` was marked.
    public func recordEvent(_ name: String, trigger: String) {
        let slot = Slot(key: Key(name: name, trigger: trigger), isEvent: true)
        slots.withLock { slots in
            slots[slot, default: Totals()].count += 1
        }
    }

    /// What the summary holds now; `now` is when it is read.
    public func snapshot(now: ContinuousClock.Instant = .now) -> Snapshot {
        let slots = slots.withLock { $0 }
        var snapshot = Snapshot(elapsed: max(now - started, .zero))
        for (slot, totals) in slots {
            if slot.isEvent {
                snapshot.events[slot.key] = totals.count
            } else {
                snapshot.intervals[slot.key] = totals
            }
        }
        return snapshot
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

    /// By name, then by trigger.
    func precedes(_ other: Self) -> Bool {
        (name, trigger) < (other.name, other.trigger)
    }
}

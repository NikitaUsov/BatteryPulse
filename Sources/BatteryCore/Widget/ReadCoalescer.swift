import Foundation

/// The logic of the widget's read cache: every request within ``window`` of a read shares that
/// read, whether it is still running or done, so a burst of timeline reloads (several placed
/// widgets, or the system asking for a snapshot and a timeline at once) reads the battery once.
///
/// A plain value with the caller's clock: the widget keeps it behind a `Mutex`, with `Pending` an
/// in-flight `Task` that joining requests await; the tests pass their own times.
public struct ReadCoalescer<Value: Sendable, Pending: Sendable>: Sendable {
    /// How long a read answers later requests.
    public static var window: TimeInterval { 5 }

    /// What a request does.
    public enum Step: Sendable {
        /// Use a read that finished within the window.
        case cached(Value)
        /// Wait for the read that is running.
        case join(Pending)
        /// Wait for the read just started, then report it with ``ReadCoalescer/finish(_:with:)``.
        case started(Pending, id: Int)
    }

    /// The last read: its result once it finished well, its handle while it runs.
    private var value: Value?
    private var pending: Pending?
    private var since = Date.distantPast
    private var lastID = 0

    public init() {}

    /// The step for a request at `now`. `start` makes the new read's pending handle; it is called
    /// only when a read starts, while the caller holds its lock.
    public mutating func request(at now: Date, start: () -> Pending) -> Step {
        // A read that never reported back stops answering after the window too.
        if now.timeIntervalSince(since) < Self.window {
            if let value { return .cached(value) }
            if let pending { return .join(pending) }
        }
        lastID += 1
        let started = start()
        (value, pending, since) = (nil, started, now)
        return .started(started, id: lastID)
    }

    /// Reports the read `id` started; `nil` means it failed, which is never cached, so the next
    /// request reads again. A report from a read already replaced is ignored.
    public mutating func finish(_ id: Int, with value: Value?) {
        guard id == lastID, pending != nil else { return }
        pending = nil
        self.value = value
        if value == nil { since = .distantPast }
    }
}

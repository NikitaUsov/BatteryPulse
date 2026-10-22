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

    private enum State: Sendable {
        case idle
        case reading(id: Int, since: Date, Pending)
        case done(Value, since: Date)
    }

    private var state = State.idle
    private var lastID = 0

    public init() {}

    /// The step for a request at `now`. `start` makes the new read's pending handle; it is called
    /// only when a read starts, while the caller holds its lock.
    public mutating func request(at now: Date, start: () -> Pending) -> Step {
        switch state {
        case .done(let value, let since) where now.timeIntervalSince(since) < Self.window:
            return .cached(value)
        // A read that never reported back stops answering after the window.
        case .reading(_, let since, let pending) where now.timeIntervalSince(since) < Self.window:
            return .join(pending)
        case .idle, .done, .reading:
            lastID += 1
            let pending = start()
            state = .reading(id: lastID, since: now, pending)
            return .started(pending, id: lastID)
        }
    }

    /// Reports the read `id` started; `nil` means it failed, which is never cached, so the next
    /// request reads again. A report from a read already replaced is ignored.
    public mutating func finish(_ id: Int, with value: Value?) {
        guard case .reading(let current, let since, _) = state, current == id else { return }
        state = value.map { .done($0, since: since) } ?? .idle
    }
}

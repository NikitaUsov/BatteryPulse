import Foundation
import Testing

@testable import BatteryCore

struct WidgetReadCoalescerTests {
    /// A manual clock and the reads it started.
    struct Harness {
        var coalescer = ReadCoalescer<Int, String>()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        var reads = 0

        mutating func request() -> ReadCoalescer<Int, String>.Step {
            var started = reads
            let step = coalescer.request(at: now) {
                started += 1
                return "read \(started)"
            }
            reads = started
            return step
        }

        mutating func advance(_ seconds: TimeInterval) {
            now = now.addingTimeInterval(seconds)
        }
    }

    @Test func concurrentRequestsWithinTheWindowShareOneRead() {
        var h = Harness()
        guard case .started(let pending, let id) = h.request() else {
            Issue.record("The first request starts a read")
            return
        }
        #expect(pending == "read 1")
        for _ in 0..<9 {
            h.advance(0.4)
            guard case .join(let joined) = h.request() else {
                Issue.record("A request during the read joins it")
                return
            }
            #expect(joined == pending)
        }
        h.coalescer.finish(id, with: 42)
        h.advance(1)
        guard case .cached(let value) = h.request() else {
            Issue.record("A request within the window uses the finished read")
            return
        }
        #expect(value == 42)
        #expect(h.reads == 1)
    }

    @Test func aRequestAfterTheWindowReadsAgain() {
        var h = Harness()
        guard case .started(_, let id) = h.request() else {
            Issue.record("Unexpected step")
            return
        }
        h.coalescer.finish(id, with: 42)
        h.advance(ReadCoalescer<Int, String>.window)
        guard case .started(let pending, _) = h.request() else {
            Issue.record("A request after the window starts a read")
            return
        }
        #expect(pending == "read 2")
        #expect(h.reads == 2)
    }

    @Test func aFailedReadIsNotCached() {
        var h = Harness()
        guard case .started(_, let id) = h.request() else {
            Issue.record("Unexpected step")
            return
        }
        h.advance(1)
        guard case .join = h.request() else {
            Issue.record("Unexpected step")
            return
        }
        h.coalescer.finish(id, with: nil)
        h.advance(1)
        guard case .started = h.request() else {
            Issue.record("A request after a failed read reads again")
            return
        }
        #expect(h.reads == 2)
    }

    /// A read that never reports back stops answering after the window, and its late report
    /// doesn't replace the newer read.
    @Test func aLostReadIsReplaced() {
        var h = Harness()
        guard case .started(_, let lost) = h.request() else {
            Issue.record("Unexpected step")
            return
        }
        h.advance(6)
        guard case .started(_, let id) = h.request() else {
            Issue.record("A read that never reported back is replaced")
            return
        }
        h.coalescer.finish(lost, with: 1)
        h.advance(1)
        guard case .join = h.request() else {
            Issue.record("The lost read's report is ignored")
            return
        }
        h.coalescer.finish(id, with: 2)
        guard case .cached(let value) = h.request() else {
            Issue.record("Unexpected step")
            return
        }
        #expect(value == 2)
        #expect(h.reads == 2)
    }
}

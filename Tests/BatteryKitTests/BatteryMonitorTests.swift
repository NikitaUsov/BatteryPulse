import BatteryCore
import Foundation
import Synchronization
import Testing

@testable import BatteryKit

@MainActor
final class MockBatteryProvider: BatteryProvider {
    var next: BatteryReading?
    private(set) var readCount = 0
    /// What each read was asked to fetch.
    private(set) var scopes: [BatteryReadScope] = []
    private(set) var handler: (@MainActor @Sendable () -> Void)?
    let cancellations = Counter()

    init(next: BatteryReading?) {
        self.next = next
    }

    func read() -> BatteryReading? {
        readCount += 1
        return next
    }

    func read(scope: BatteryReadScope) -> BatteryReading? {
        scopes.append(scope)
        return read()
    }

    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        self.handler = handler
        let cancellations = cancellations
        return BatteryObservation { cancellations.increment() }
    }

    func simulateSystemChange() {
        handler?()
    }
}

/// A provider with no slow values: it only implements the full read.
@MainActor
private final class FullReadProvider: BatteryProvider {
    private(set) var readCount = 0

    func read() -> BatteryReading? {
        readCount += 1
        return nil
    }

    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        BatteryObservation {}
    }
}

final class Counter: Sendable {
    private let count = Mutex(0)
    var value: Int { count.withLock { $0 } }
    func increment() { count.withLock { $0 += 1 } }
}

/// A clock that stands still until a test advances it, so each of the monitor's sleeps (the
/// polls, the follow-ups, the coalescing window) ends exactly when the test says, however busy
/// the machine is. It records what every sleep asked for.
final class ManualMonitorClock: MonitorClock {
    struct Sleep: Equatable {
        let delay: Duration
        let tolerance: Duration?
    }

    private struct Sleeper {
        let deadline: ContinuousClock.Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = ContinuousClock.now
        var nextID = 0
        var sleepers: [Int: Sleeper] = [:]
        var sleeps: [Sleep] = []
    }

    private let state = Mutex(State())

    var now: ContinuousClock.Instant { state.withLock { $0.now } }
    var minimumResolution: Duration { .zero }
    /// The sleeps that haven't ended.
    var sleeperCount: Int { state.withLock { $0.sleepers.count } }
    /// What every sleep asked for, oldest first.
    var sleeps: [Sleep] { state.withLock { $0.sleeps } }

    func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
        let id = state.withLock { state in
            state.sleeps.append(Sleep(delay: deadline - state.now, tolerance: tolerance))
            state.nextID += 1
            return state.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let result: Result<Void, any Error>? = state.withLock { state in
                    if Task.isCancelled { return .failure(CancellationError()) }
                    if deadline <= state.now { return .success(()) }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let result { continuation.resume(with: result) }
            }
        } onCancel: {
            let sleeper = state.withLock { $0.sleepers.removeValue(forKey: id) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward and ends the sleeps that are now due, earliest first.
    func advance(by duration: Duration) {
        let due = state.withLock { state in
            state.now += duration
            let now = state.now
            let due = state.sleepers.filter { $0.value.deadline <= now }.sorted {
                $0.value.deadline < $1.value.deadline
            }
            for (id, _) in due { state.sleepers[id] = nil }
            return due.map(\.value.continuation)
        }
        for continuation in due { continuation.resume() }
    }
}

/// Lets the tasks that the clock woke run until `condition` holds. The clock stands still
/// meanwhile, so nothing else can happen; the bound only ends a broken test instead of hanging it.
@MainActor
private func settle(until condition: () -> Bool) async {
    let deadline = ContinuousClock.now + .seconds(10)
    while !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(1))
    }
}

private func reading(percent: Double, at seconds: TimeInterval) -> BatteryReading {
    BatteryReading(
        snapshot: BatterySnapshot(
            timestamp: Date(timeIntervalSince1970: seconds),
            chargePercent: percent,
            chargeState: .discharging
        ))
}

private func reading(connected: Bool) -> BatteryReading {
    BatteryReading(
        snapshot: BatterySnapshot(
            timestamp: Date(timeIntervalSince1970: 1), chargePercent: 50,
            chargeState: connected ? .notCharging : .discharging, isExternalPowerConnected: connected))
}

/// Every timed step runs on a ``ManualMonitorClock``: the tests count reads and never measure time.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct BatteryMonitorTests {
    let clock = ManualMonitorClock()

    private func makeMonitor(_ provider: MockBatteryProvider) -> BatteryMonitor {
        BatteryMonitor(provider: provider, clock: clock)
    }

    /// Posts one change notification and ends its coalescing window: one read.
    private func notifyAndRead(_ provider: MockBatteryProvider) async {
        let reads = provider.readCount
        let sleepers = clock.sleeperCount
        provider.simulateSystemChange()
        await settle { clock.sleeperCount == sleepers + 1 }
        clock.advance(by: BatteryMonitor.coalescingWindow)
        await settle { provider.readCount == reads + 1 }
    }

    @Test func startReadsImmediatelyAndSubscribes() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        #expect(monitor.hasBattery == nil)

        monitor.start()
        #expect(monitor.isRunning)
        #expect(provider.readCount == 1)
        #expect(provider.handler != nil)
        #expect(monitor.snapshot?.chargePercent == 80)
        #expect(monitor.hasBattery == true)
    }

    @Test func notificationBurstIsOneRead() async throws {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        provider.next = reading(percent: 79, at: 2)
        for _ in 0..<5 { provider.simulateSystemChange() }
        #expect(provider.readCount == 1, "the read waits for the burst to end")
        await settle { clock.sleeperCount == 1 }
        let window = try #require(clock.sleeps.last)
        #expect(window == .init(delay: .milliseconds(150), tolerance: .milliseconds(100)))
        // The longest a plug or unplug waits to be shown.
        #expect(window.delay + (window.tolerance ?? .zero) <= .milliseconds(250))

        // A notification later in the burst joins the pending read rather than extending it.
        clock.advance(by: .milliseconds(100))
        provider.simulateSystemChange()
        clock.advance(by: .milliseconds(49))
        #expect(clock.sleeperCount == 1, "149 ms after the first notification, the read still waits")
        #expect(provider.readCount == 1)
        clock.advance(by: .milliseconds(1))
        await settle { provider.readCount == 2 }
        #expect(provider.readCount == 2)
        #expect(clock.sleeperCount == 0)
        #expect(monitor.snapshot?.chargePercent == 79)

        await notifyAndRead(provider)
        #expect(provider.readCount == 3, "a later notification reads again")
    }

    @Test func readingNowReplacesAPendingRead() async {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        provider.simulateSystemChange()
        await settle { clock.sleeperCount == 1 }
        monitor.refresh()
        #expect(provider.readCount == 2)
        #expect(clock.sleeperCount == 0, "the notification's read is no longer needed")
        clock.advance(by: .seconds(1))
        #expect(provider.readCount == 2)
    }

    @Test func idleMonitorDoesNotRead() async {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()
        #expect(clock.sleeperCount == 0, "no timer without a live-refresh client")

        // A client that comes and goes leaves no timer behind.
        clock.advance(by: .seconds(5))
        monitor.setLiveRefreshInterval(.seconds(10), for: "popover")
        await settle { clock.sleeperCount == 1 }
        monitor.setLiveRefreshInterval(nil, for: "popover")
        #expect(clock.sleeperCount == 0)
        let reads = provider.readCount

        clock.advance(by: .seconds(3600))
        #expect(provider.readCount == reads, "an hour without clients or notifications reads nothing")
    }

    @Test func identicalStateKeepsOriginalSnapshot() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        provider.next = reading(percent: 80, at: 2)
        monitor.refresh()
        // Only the timestamp changed, so the snapshot (and the views reading it) stay put.
        #expect(monitor.snapshot?.timestamp == Date(timeIntervalSince1970: 1))
        #expect(monitor.reading?.snapshot.timestamp == Date(timeIntervalSince1970: 1))
    }

    @Test func everyReadIsStamped() throws {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        #expect(monitor.lastReadAt == nil)

        monitor.start()
        let first = try #require(monitor.lastReadAt)
        #expect(first == clock.now)
        clock.advance(by: .seconds(5))
        provider.next = reading(percent: 80, at: 2)
        monitor.refresh()
        // The snapshot keeps its timestamp, since only that changed, but the read still counts.
        #expect(monitor.snapshot?.timestamp == Date(timeIntervalSince1970: 1))
        #expect(monitor.lastReadAt == first + .seconds(5))
    }

    @Test func changedRawDataRepublishesReading() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        var next = reading(percent: 80, at: 2)
        next.smartBattery = ["UpdateTime": .int(2)]
        provider.next = next
        monitor.refresh()
        #expect(monitor.reading?.smartBattery["UpdateTime"] == .int(2))
        #expect(monitor.snapshot?.timestamp == Date(timeIntervalSince1970: 1))
    }

    @Test func overrideReplacesReadingsUntilCleared() async {
        let device = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        let demo = DemoBatteryProvider(battery: DemoScenario.lowBattery.battery)
        monitor.setOverride(demo)
        #expect(monitor.isOverridden)
        #expect(monitor.snapshot?.chargePercent == 17)
        #expect(device.cancellations.value == 1, "device notifications pause during the demo")

        // Changing the demo updates the monitor at once, without a device event.
        demo.battery = DemoScenario.criticalBattery.battery
        #expect(monitor.snapshot?.chargePercent == 6)
        demo.battery = nil
        #expect(monitor.hasBattery == false)

        monitor.setOverride(nil)
        #expect(!monitor.isOverridden)
        #expect(monitor.snapshot?.chargePercent == 80)
        #expect(monitor.hasBattery == true)
        device.next = reading(percent: 79, at: 2)
        await notifyAndRead(device)
        #expect(monitor.snapshot?.chargePercent == 79, "device notifications resume")
    }

    @Test func missingBatteryIsReported() {
        let provider = MockBatteryProvider(next: nil)
        let monitor = makeMonitor(provider)
        monitor.start()
        #expect(monitor.hasBattery == false)
        #expect(monitor.snapshot == nil)
    }

    @Test func stopCancelsObservation() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()
        monitor.start()  // idempotent
        #expect(provider.readCount == 1)

        monitor.stop()
        #expect(!monitor.isRunning)
        #expect(provider.cancellations.value == 1)
    }

    @Test func stopCancelsAPendingRead() async {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        provider.simulateSystemChange()
        await settle { clock.sleeperCount == 1 }
        monitor.stop()
        #expect(clock.sleeperCount == 0)
        clock.advance(by: .seconds(1))
        #expect(provider.readCount == 1)
    }

    @Test func liveRefreshPollsOnlyWhileEnabled() async {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        clock.advance(by: .seconds(5))
        monitor.setLiveRefreshInterval(.seconds(10))
        #expect(provider.readCount == 2, "a new request reads at once")
        await settle { clock.sleeperCount == 1 }
        #expect(clock.sleeps.last == .init(delay: .seconds(10), tolerance: .milliseconds(2500)))
        for poll in 1...3 {
            clock.advance(by: .seconds(10))
            await settle { provider.readCount == 2 + poll && clock.sleeperCount == 1 }
        }
        #expect(provider.readCount == 5)

        monitor.setLiveRefreshInterval(nil)
        #expect(clock.sleeperCount == 0)
        clock.advance(by: .seconds(3600))
        #expect(provider.readCount == 5)
    }

    @Test func shortestLiveRefreshRequestWins() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        clock.advance(by: .seconds(5))
        monitor.setLiveRefreshInterval(.seconds(15), for: "menuBar")
        monitor.setLiveRefreshInterval(.seconds(2), for: "popover")
        #expect(monitor.liveRefreshInterval == .seconds(2))
        // Opening a view refreshes right away instead of after the first interval; the second
        // view uses that read.
        #expect(provider.readCount == 2)

        monitor.setLiveRefreshInterval(nil, for: "popover")
        #expect(monitor.liveRefreshInterval == .seconds(15))
        monitor.setLiveRefreshInterval(nil, for: "menuBar")
        #expect(monitor.liveRefreshInterval == nil)
        #expect(provider.readCount == 2)
        monitor.stop()
    }

    @Test func newRequestReusesARecentRead() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        // At launch the menu bar asks for polling right after the first read.
        monitor.setLiveRefreshInterval(.seconds(10), for: "menuBar")
        #expect(provider.readCount == 1)
        #expect(monitor.hasRead(within: .seconds(1)))
        clock.advance(by: .milliseconds(999))
        monitor.setLiveRefreshInterval(.seconds(2), for: "popover")
        #expect(provider.readCount == 1, "a read under a second old is fresh enough")

        clock.advance(by: .milliseconds(1))
        #expect(!monitor.hasRead(within: .seconds(1)))
        monitor.setLiveRefreshInterval(.seconds(2), for: "compact")
        #expect(provider.readCount == 2)
        #expect(monitor.hasRead(within: .seconds(1)))
        monitor.stop()
    }

    @Test func pluggingInIsFollowedByExtraReads() async {
        let provider = MockBatteryProvider(next: reading(connected: false))
        let monitor = makeMonitor(provider)
        monitor.start()
        await notifyAndRead(provider)
        #expect(provider.readCount == 2)
        #expect(clock.sleeperCount == 0, "no change of power source, no extra reads")

        provider.next = reading(connected: true)
        await notifyAndRead(provider)
        await settle { clock.sleeperCount == 1 }
        var elapsed = Duration.zero
        let delays = monitor.powerChangeFollowUps
        for (index, delay) in delays.enumerated() {
            clock.advance(by: delay - elapsed)
            elapsed = delay
            // Each read but the last is followed by the sleep until the next.
            let sleepers = index < delays.count - 1 ? 1 : 0
            await settle { provider.readCount == 4 + index && clock.sleeperCount == sleepers }
        }
        #expect(provider.readCount == 8)
        #expect(clock.sleeperCount == 0)
        // Each sleep may end up to a tenth of its gap late.
        let gaps: [Duration] = [.seconds(3), .seconds(5), .seconds(7), .seconds(15), .seconds(30)]
        #expect(Array(clock.sleeps.suffix(5)) == gaps.map { .init(delay: $0, tolerance: $0 / 10) })

        // Stopping cancels pending follow-ups.
        provider.next = reading(connected: false)
        await notifyAndRead(provider)
        await settle { clock.sleeperCount == 1 }
        monitor.stop()
        #expect(clock.sleeperCount == 0)
        clock.advance(by: .seconds(60))
        #expect(provider.readCount == 9)
    }

    @Test func liveRefreshStopsWithMonitor() async {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.setLiveRefreshInterval(.seconds(10))
        #expect(clock.sleeperCount == 0, "not started yet: no polling")
        clock.advance(by: .seconds(60))
        #expect(provider.readCount == 0)

        monitor.start()
        await settle { clock.sleeperCount == 1 }
        clock.advance(by: .seconds(10))
        await settle { provider.readCount == 2 && clock.sleeperCount == 1 }
        monitor.stop()
        #expect(provider.readCount == 2)
        #expect(clock.sleeperCount == 0)
        clock.advance(by: .seconds(60))
        #expect(provider.readCount == 2)
    }

    // MARK: - Slow values

    @Test func slowValuesAtMostOnceAMinute() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()
        #expect(provider.scopes == [.full], "the first read fetches everything")

        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        clock.advance(by: .seconds(57))
        monitor.refresh(trigger: .notify)
        #expect(provider.scopes == [.full, .live, .live])
        clock.advance(by: .seconds(1))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes.last == .full, "a minute after the last full read")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes.last == .live)
    }

    @Test func aViewThatShowsSlowValuesGetsThemOnEveryRead() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        monitor.setShowsSlowValues(true, for: "main")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        monitor.setShowsSlowValues(true, for: "popover")
        monitor.setShowsSlowValues(false, for: "main")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes == [.full, .full, .full], "while any client shows them")

        monitor.setShowsSlowValues(false, for: "popover")
        monitor.setShowsSlowValues(false, for: "popover")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes.last == .live)
        clock.advance(by: .seconds(58))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes.last == .full, "the minute counts from the last full read")
    }

    @Test func aManualReadFetchesSlowValues() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        clock.advance(by: .seconds(2))
        monitor.refresh()
        #expect(provider.scopes == [.full, .full], "Copy Report takes every value fresh")
        clock.advance(by: .seconds(30))
        monitor.refresh(trigger: .poll)
        // 61 s after the launch read, 59 s after the manual one.
        clock.advance(by: .seconds(29))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes == [.full, .full, .live, .live], "the minute counts from the manual read")
    }

    @Test func leavingDemoModeReadsSlowValuesAgain() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let demo = MockBatteryProvider(next: reading(percent: 50, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        monitor.setOverride(demo)
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .demo)
        monitor.setOverride(nil)
        #expect(demo.scopes == [.full, .live])
        #expect(provider.scopes == [.full, .full], "the device's slow values are as old as the demo")
    }

    @Test func providersWithoutSlowValuesReadInFull() {
        let provider = FullReadProvider()
        #expect(provider.read(scope: .live) == nil)
        #expect(provider.readCount == 1)
    }
}

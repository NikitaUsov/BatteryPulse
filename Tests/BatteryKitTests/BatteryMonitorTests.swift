import BatteryCore
import BatterySource
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
    /// Whether each read was asked to fetch the registry.
    var registryReads: [Bool] { scopes.map(\.rereadsRegistry) }
    /// Whether each read was asked for every SMC key.
    var allSMCKeyReads: [Bool] { scopes.map(\.readsAllSMCKeys) }
    private(set) var handler: (@MainActor @Sendable () -> Void)?
    let cancellations = LockedValue(0)

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

/// Reads off the main actor that wait until the test ends them, oldest first. It records what each
/// asked for, how many waited at once, and whether any ran on the main actor.
final class SuspendingReader: NonisolatedBatteryReader {
    private struct State {
        var waiting: [CheckedContinuation<BatteryReading?, Never>] = []
        var scopes: [BatteryReadScope] = []
        var mostAtOnce = 0
        var ranOnMainActor = false
    }

    private let state = Mutex(State())

    func readNonisolated(scope: BatteryReadScope) async -> BatteryReading? {
        // The caller's isolation: the monitor's `@concurrent` helper has none.
        let isolation = #isolation
        let onMainActor = isolation != nil || Thread.isMainThread
        return await withCheckedContinuation { continuation in
            state.withLock { state in
                state.scopes.append(scope)
                state.waiting.append(continuation)
                state.mostAtOnce = max(state.mostAtOnce, state.waiting.count)
                if onMainActor { state.ranOnMainActor = true }
            }
        }
    }

    /// How many reads began.
    var started: Int { state.withLock { $0.scopes.count } }
    /// What every read asked for, oldest first.
    var scopes: [BatteryReadScope] { state.withLock { $0.scopes } }
    /// The reads that wait for ``finish(with:)``.
    var inFlight: Int { state.withLock { $0.waiting.count } }
    var mostAtOnce: Int { state.withLock { $0.mostAtOnce } }
    var ranOnMainActor: Bool { state.withLock { $0.ranOnMainActor } }

    /// Ends the oldest read in flight with `reading`.
    func finish(with reading: BatteryReading?) {
        let continuation = state.withLock { $0.waiting.isEmpty ? nil : $0.waiting.removeFirst() }
        continuation?.resume(returning: reading)
    }
}

/// A device's provider whose reads off the main actor wait for the test (``SuspendingReader``),
/// while its reads on the main actor return ``next`` at once.
@MainActor
final class SuspendingProvider: BatteryProvider {
    let reader = SuspendingReader()
    var next: BatteryReading?
    private(set) var mainActorReads = 0
    private var handler: (@MainActor @Sendable () -> Void)?

    init(next: BatteryReading?) {
        self.next = next
    }

    func read() -> BatteryReading? {
        mainActorReads += 1
        return next
    }

    var nonisolatedReader: (any NonisolatedBatteryReader)? { reader }

    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        self.handler = handler
        return BatteryObservation {}
    }

    func simulateSystemChange() {
        handler?()
    }
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

/// A reading whose registry the gauge last updated `seconds` after 1970 (`UpdateTime`).
private func reading(updated seconds: TimeInterval) -> BatteryReading {
    var reading = reading(percent: 80, at: 1)
    reading.snapshot.gaugeUpdatedAt = Date(timeIntervalSince1970: seconds)
    return reading
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

    private func makeMonitor(
        _ provider: MockBatteryProvider, cachesOnPolls: Bool = RegistryReadPolicy.cachesOnPolls
    ) -> BatteryMonitor {
        BatteryMonitor(
            provider: provider, clock: clock, registryPolicy: RegistryReadPolicy(cachesOnPolls: cachesOnPolls))
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

    @Test(arguments: [true, false])
    func slowValuesAtMostOnceAMinute(cachesOnPolls: Bool) {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()
        #expect(provider.scopes == [.full], "the first read fetches everything")

        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        clock.advance(by: .seconds(57))
        monitor.refresh(trigger: .notify)
        #expect(provider.allSMCKeyReads == [true, false, false])
        clock.advance(by: .seconds(1))
        monitor.refresh(trigger: .poll)
        #expect(provider.allSMCKeyReads.last == true, "a minute after the last full read")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(provider.allSMCKeyReads.last == false)
    }

    @Test(arguments: [true, false])
    func aViewThatShowsSlowValuesGetsThemOnEveryRead(cachesOnPolls: Bool) {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()

        monitor.setShowsSlowValues(true, for: "main")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        monitor.setShowsSlowValues(true, for: "popover")
        monitor.setShowsSlowValues(false, for: "main")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes == [.full, .full, .full], "while any client shows them, the registry too")

        monitor.setShowsSlowValues(false, for: "popover")
        monitor.setShowsSlowValues(false, for: "popover")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes.last == (cachesOnPolls ? .cached : .live))
        clock.advance(by: .seconds(58))
        monitor.refresh(trigger: .poll)
        #expect(
            provider.scopes.last == (cachesOnPolls ? .cachedSlow : .full), "the minute counts from the last full read")
    }

    @Test(arguments: [true, false])
    func aManualReadFetchesSlowValues(cachesOnPolls: Bool) {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()

        clock.advance(by: .seconds(2))
        monitor.refresh()
        #expect(provider.scopes == [.full, .full], "Copy Report takes every value fresh")
        clock.advance(by: .seconds(30))
        monitor.refresh(trigger: .poll)
        // 61 s after the launch read, 59 s after the manual one.
        clock.advance(by: .seconds(29))
        monitor.refresh(trigger: .poll)
        #expect(provider.allSMCKeyReads == [true, true, false, false], "the minute counts from the manual read")
    }

    @Test(arguments: [true, false])
    func leavingDemoModeReadsSlowValuesAgain(cachesOnPolls: Bool) {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let demo = MockBatteryProvider(next: reading(percent: 50, at: 1))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()

        monitor.setOverride(demo)
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .demo)
        monitor.setOverride(nil)
        #expect(demo.scopes == [.full, .live])
        #expect(provider.scopes == [.full, .full], "the device's values are as old as the demo")
    }

    // MARK: - The registry

    /// Every trigger but a poll fetches the registry: a notification's, a follow-up, the launch, the
    /// history's sample (which covers wake), Demo Mode's and a manual read.
    @Test(arguments: [true, false])
    func everyReadButAPollFetchesTheRegistry(cachesOnPolls: Bool) {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()
        for trigger in [RefreshTrigger.notify, .followUp, .history, .demo, .manual] {
            clock.advance(by: .seconds(1))
            monitor.refresh(trigger: trigger)
        }
        clock.advance(by: .seconds(1))
        monitor.refresh(trigger: .poll)
        #expect(provider.registryReads == [true, true, true, true, true, true, !cachesOnPolls])
    }

    /// Polls every 10 s, as with power in the menu bar: they reuse the registry until it is 5 minutes
    /// old, and the 5 minutes count from the last read that fetched it, whatever its trigger.
    @Test(arguments: [true, false])
    func aPollReusesTheRegistryForFiveMinutes(cachesOnPolls: Bool) {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()
        for _ in 0..<29 {
            clock.advance(by: .seconds(10))
            monitor.refresh(trigger: .poll)
        }
        #expect(provider.registryReads == [true] + Array(repeating: !cachesOnPolls, count: 29))
        clock.advance(by: .seconds(10))
        monitor.refresh(trigger: .poll)
        #expect(provider.registryReads.last == true, "5 minutes after the launch read: the safety net")
        clock.advance(by: .seconds(10))
        monitor.refresh(trigger: .poll)
        #expect(provider.registryReads.last == !cachesOnPolls)

        clock.advance(by: .seconds(200))
        monitor.refresh(trigger: .notify)
        clock.advance(by: .seconds(200))
        monitor.refresh(trigger: .poll)
        #expect(provider.registryReads.suffix(2) == [true, !cachesOnPolls], "200 s after the notification's read")
    }

    @Test(arguments: [true, false])
    func aPollFetchesTheRegistryWhilePowerOrRawDataIsShown(cachesOnPolls: Bool) {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()

        monitor.setShowsSlowValues(true, for: "main")
        for _ in 0..<3 {
            clock.advance(by: .seconds(2))
            monitor.refresh(trigger: .poll)
        }
        monitor.setShowsSlowValues(false, for: "main")
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(provider.registryReads == [true, true, true, true, !cachesOnPolls])
    }

    /// The adapter going in is a notification, which fetches the registry, and so does each of the
    /// extra reads after it, while the registry and macOS catch up.
    @Test(arguments: [true, false])
    func pluggingInFetchesTheRegistryOnEveryFollowUp(cachesOnPolls: Bool) async {
        let provider = MockBatteryProvider(next: reading(connected: false))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()
        clock.advance(by: .seconds(10))
        monitor.refresh(trigger: .poll)

        provider.next = reading(connected: true)
        await notifyAndRead(provider)
        #expect(provider.scopes.last == .live, "the registry, and the SMC's live pair 10 s after the launch read")
        await settle { clock.sleeperCount == 1 }
        var elapsed = Duration.zero
        let delays = monitor.powerChangeFollowUps
        for (index, delay) in delays.enumerated() {
            clock.advance(by: delay - elapsed)
            elapsed = delay
            let sleepers = index < delays.count - 1 ? 1 : 0
            await settle { provider.readCount == 4 + index && clock.sleeperCount == sleepers }
        }
        #expect(provider.registryReads == [true, !cachesOnPolls] + Array(repeating: true, count: 1 + delays.count))
    }

    @Test func providersWithoutSlowValuesReadInFull() {
        let provider = FullReadProvider()
        #expect(provider.read(scope: .live) == nil)
        #expect(provider.readCount == 1)
    }

    // MARK: - Registry updates without a notification

    /// Power is on screen, so every poll fetches the registry: one that finds new data although no
    /// notification came since the last fetch logs `registry.missed`.
    @Test(arguments: [true, false])
    func anUpdateWithoutANotificationIsMissed(cachesOnPolls: Bool) async {
        let provider = MockBatteryProvider(next: reading(updated: 100))
        let monitor = makeMonitor(provider, cachesOnPolls: cachesOnPolls)
        monitor.start()
        monitor.setShowsSlowValues(true, for: "main")

        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(monitor.missedRegistryUpdates == 0, "the same data")
        provider.next = reading(updated: 160)
        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        #expect(monitor.missedRegistryUpdates == 1)

        provider.next = reading(updated: 220)
        await notifyAndRead(provider)
        #expect(monitor.missedRegistryUpdates == 1, "announced")
        #expect(provider.registryReads.allSatisfy { $0 })
    }

    /// Only a read that fetched the registry has news of it.
    @Test func aPollThatReusesTheRegistryIsNotChecked() {
        let provider = MockBatteryProvider(next: reading(updated: 100))
        let monitor = makeMonitor(provider, cachesOnPolls: true)
        monitor.start()

        provider.next = reading(updated: 160)
        clock.advance(by: .seconds(10))
        monitor.refresh(trigger: .poll)
        #expect(provider.scopes.last == .cached)
        #expect(monitor.missedRegistryUpdates == 0)
    }

    /// The registry changed just before a read fetched it, and its notification came while the read
    /// was under way: neither that read nor the notification's own counts a miss.
    @Test func aNotificationDuringAReadAnnouncesItsChange() async {
        let device = SuspendingProvider(next: reading(updated: 100))
        let monitor = makeMonitor(device)
        monitor.start()
        monitor.setShowsSlowValues(true, for: "main")

        clock.advance(by: .seconds(2))
        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        device.simulateSystemChange()
        await settle { clock.sleeperCount == 1 }
        device.reader.finish(with: reading(updated: 160))
        await settle { !monitor.isReadingOffMainActor }
        clock.advance(by: BatteryMonitor.coalescingWindow)
        await settle { device.reader.inFlight == 1 }
        device.reader.finish(with: reading(updated: 160))
        await settle { !monitor.isReadingOffMainActor }
        #expect(device.reader.started == 2)
        #expect(monitor.missedRegistryUpdates == 0)
    }

    /// Demo Mode and a stop pause the device's notifications: the data found after them is no miss.
    @Test func aPauseOfTheNotificationsIsNoMiss() {
        let provider = MockBatteryProvider(next: reading(updated: 100))
        let monitor = makeMonitor(provider)
        monitor.start()

        monitor.setOverride(DemoBatteryProvider(battery: DemoScenario.lowBattery.battery))
        provider.next = reading(updated: 160)
        monitor.setOverride(nil)
        monitor.stop()
        provider.next = reading(updated: 220)
        monitor.start()
        #expect(provider.readCount == 3)
        #expect(monitor.missedRegistryUpdates == 0)

        provider.next = reading(updated: 280)
        monitor.refresh()
        #expect(monitor.missedRegistryUpdates == 1, "the manual read found news no notification told of")
    }

    // MARK: - Reads off the main actor

    private func makeMonitor(
        _ provider: SuspendingProvider, cachesOnPolls: Bool = RegistryReadPolicy.cachesOnPolls
    ) -> BatteryMonitor {
        BatteryMonitor(
            provider: provider, clock: clock, registryPolicy: RegistryReadPolicy(cachesOnPolls: cachesOnPolls))
    }

    /// The launch read (the one before `menuBarReady`), a manual one (Copy Report reads the snapshot
    /// right after) and Demo Mode's (animated with DemoController's own changes) are done when the
    /// call returns.
    @Test func launchManualAndDemoReadsStayOnTheMainActor() {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()
        #expect(device.mainActorReads == 1)
        #expect(monitor.snapshot?.chargePercent == 80)

        device.next = reading(percent: 79, at: 2)
        monitor.refresh()
        #expect(monitor.snapshot?.chargePercent == 79)
        monitor.setOverride(DemoBatteryProvider(battery: DemoScenario.lowBattery.battery))
        #expect(monitor.snapshot?.chargePercent == 17)
        monitor.setOverride(nil)
        #expect(monitor.snapshot?.chargePercent == 79, "the device's values come back at once")
        #expect(device.mainActorReads == 3)
        #expect(device.reader.started == 0)
        #expect(!monitor.isReadingOffMainActor)
    }

    @Test(arguments: [RefreshTrigger.notify, .poll, .followUp, .history])
    func otherReadsRunOffTheMainActor(_ trigger: RefreshTrigger) async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        clock.advance(by: .seconds(5))
        monitor.refresh(trigger: trigger)
        #expect(monitor.isReadingOffMainActor)
        await settle { device.reader.inFlight == 1 }
        #expect(monitor.snapshot?.chargePercent == 80, "nothing changes until the read lands")
        #expect(!device.reader.ranOnMainActor)
        #expect(device.reader.scopes == [trigger == .poll && RegistryReadPolicy.cachesOnPolls ? .cached : .live])

        device.reader.finish(with: reading(percent: 79, at: 2))
        await settle { !monitor.isReadingOffMainActor }
        #expect(monitor.snapshot?.chargePercent == 79)
        #expect(monitor.reading?.snapshot.chargePercent == 79)
        #expect(monitor.lastReadAt == clock.now)
        #expect(device.mainActorReads == 1, "only the launch read")
    }

    /// Two reads never run at once: what arrives during a read waits for it, and any number of
    /// requests make one follow-on read.
    @Test func requestsDuringAReadMakeOneFollowOnRead() async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        monitor.refresh(trigger: .followUp)
        monitor.refresh(trigger: .poll)
        monitor.refresh(trigger: .history)
        #expect(monitor.requestedTrigger == .followUp, "the follow-on read is labelled with the first request")
        #expect(device.reader.started == 1)

        device.reader.finish(with: reading(percent: 79, at: 2))
        await settle { device.reader.started == 2 }
        #expect(monitor.snapshot?.chargePercent == 79, "the first read is shown before the next begins")
        device.reader.finish(with: reading(percent: 78, at: 3))
        await settle { !monitor.isReadingOffMainActor }
        #expect(monitor.snapshot?.chargePercent == 78)
        #expect(device.reader.started == 2)
        #expect(device.reader.mostAtOnce == 1)
    }

    /// A burst of notifications during a read is still one read, after it.
    @Test func notificationsDuringAReadJoinTheFollowOnRead() async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        for _ in 0..<3 { device.simulateSystemChange() }
        await settle { clock.sleeperCount == 1 }
        clock.advance(by: BatteryMonitor.coalescingWindow)
        await settle { monitor.requestedTrigger == .notify }
        #expect(device.reader.started == 1)

        device.reader.finish(with: reading(percent: 79, at: 2))
        await settle { device.reader.started == 2 }
        device.reader.finish(with: reading(percent: 78, at: 3))
        await settle { !monitor.isReadingOffMainActor }
        #expect(monitor.snapshot?.chargePercent == 78)
        #expect(device.reader.started == 2)
        #expect(clock.sleeperCount == 0)
    }

    /// A follow-on read serves every request that waited for it: one that isn't a poll, such as a
    /// notification's, makes it fetch the registry, whatever the first request was.
    @Test(arguments: [true, false])
    func aFollowOnReadFetchesWhatItsRequestsNeed(cachesOnPolls: Bool) async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device, cachesOnPolls: cachesOnPolls)
        monitor.start()

        clock.advance(by: .seconds(5))
        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        monitor.refresh(trigger: .poll)
        monitor.refresh(trigger: .notify)
        monitor.refresh(trigger: .poll)
        #expect(monitor.requestedTrigger == .poll, "labelled with the first request")
        device.reader.finish(with: reading(percent: 79, at: 2))
        await settle { device.reader.started == 2 }
        device.reader.finish(with: reading(percent: 78, at: 3))
        await settle { !monitor.isReadingOffMainActor }

        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        monitor.refresh(trigger: .poll)
        device.reader.finish(with: reading(percent: 77, at: 4))
        await settle { device.reader.started == 4 }
        device.reader.finish(with: reading(percent: 76, at: 5))
        await settle { !monitor.isReadingOffMainActor }
        #expect(device.reader.scopes.map(\.rereadsRegistry) == [!cachesOnPolls, true, !cachesOnPolls, !cachesOnPolls])
    }

    @Test func aReadThatLandsInDemoModeIsDropped() async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        monitor.refresh(trigger: .history)
        monitor.setOverride(DemoBatteryProvider(battery: DemoScenario.lowBattery.battery))
        #expect(monitor.snapshot?.chargePercent == 17)
        let demoReadAt = monitor.lastReadAt

        clock.advance(by: .seconds(1))
        device.reader.finish(with: reading(percent: 79, at: 2))
        await settle { !monitor.isReadingOffMainActor }
        #expect(monitor.snapshot?.chargePercent == 17, "the device's late read doesn't replace the demo")
        #expect(monitor.lastReadAt == demoReadAt)
        #expect(device.reader.started == 1, "nor does the request that waited for it read the device")

        monitor.setOverride(nil)
        #expect(monitor.snapshot?.chargePercent == 80)
    }

    @Test func aReadThatLandsAfterStopIsDropped() async {
        let device = SuspendingProvider(next: reading(connected: false))
        let monitor = makeMonitor(device)
        monitor.start()
        let launchReadAt = monitor.lastReadAt

        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        monitor.refresh(trigger: .poll)
        monitor.stop()
        clock.advance(by: .seconds(1))
        device.reader.finish(with: reading(connected: true))
        await settle { !monitor.isReadingOffMainActor }
        #expect(monitor.snapshot?.isExternalPowerConnected == false)
        #expect(monitor.lastReadAt == launchReadAt)
        #expect(device.reader.started == 1)
        #expect(clock.sleeperCount == 0, "no extra reads for a change the stopped monitor never showed")
    }

    /// A read on the main actor during one off it is the newer: the older result is dropped, and the
    /// request that waited for a follow-on read is served.
    @Test func aManualReadSupersedesOneInFlight() async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        monitor.refresh(trigger: .poll)
        device.next = reading(percent: 70, at: 3)
        monitor.refresh()
        #expect(monitor.snapshot?.chargePercent == 70)

        device.reader.finish(with: reading(percent: 79, at: 2))
        await settle { !monitor.isReadingOffMainActor }
        #expect(monitor.snapshot?.chargePercent == 70, "the older read doesn't overwrite the newer one")
        #expect(device.reader.started == 1)
    }

    /// Stopping and starting again during a read keeps one read at a time.
    @Test func aRestartDuringAReadWaitsForIt() async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        monitor.stop()
        monitor.start()
        #expect(device.mainActorReads == 2, "the launch read")
        monitor.refresh(trigger: .poll)
        #expect(device.reader.started == 1, "the new read waits for the stale one")

        device.reader.finish(with: reading(percent: 79, at: 2))
        await settle { device.reader.started == 2 }
        #expect(monitor.snapshot?.chargePercent == 80, "the stale read is dropped")
        device.reader.finish(with: reading(percent: 78, at: 3))
        await settle { !monitor.isReadingOffMainActor }
        #expect(monitor.snapshot?.chargePercent == 78)
        #expect(device.reader.mostAtOnce == 1)
    }

    /// The history recorder's read: it returns once the snapshot holds what the read found.
    @Test func waitingForAReadReturnsWithItsResult() async {
        let device = SuspendingProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(device)
        monitor.start()

        let first = Task(name: "BatteryMonitorTests.first") {
            await monitor.refreshAndWait(trigger: .history)
            return monitor.snapshot?.chargePercent
        }
        await settle { device.reader.inFlight == 1 }
        device.reader.finish(with: reading(percent: 79, at: 2))
        #expect(await first.value == 79)

        // A request during a read waits for the follow-on read, which begins after it.
        monitor.refresh(trigger: .poll)
        await settle { device.reader.inFlight == 1 }
        let second = Task(name: "BatteryMonitorTests.second") {
            await monitor.refreshAndWait(trigger: .history)
            return monitor.snapshot?.chargePercent
        }
        await settle { monitor.requestedTrigger == .history }
        device.reader.finish(with: reading(percent: 78, at: 3))
        await settle { device.reader.started == 3 }
        device.reader.finish(with: reading(percent: 77, at: 4))
        #expect(await second.value == 77)
    }

    @Test func waitingWithAMainActorProviderReadsAtOnce() async {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = makeMonitor(provider)
        monitor.start()

        provider.next = reading(percent: 79, at: 2)
        await monitor.refreshAndWait(trigger: .history)
        #expect(monitor.snapshot?.chargePercent == 79)
        #expect(provider.readCount == 2)
    }
}

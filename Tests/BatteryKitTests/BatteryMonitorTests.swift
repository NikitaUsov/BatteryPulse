import BatteryCore
import Foundation
import Testing

@testable import BatteryKit

@MainActor
final class MockBatteryProvider: BatteryProvider {
    var next: BatteryReading?
    private(set) var readCount = 0
    private(set) var handler: (@MainActor @Sendable () -> Void)?
    let cancellations = Counter()

    init(next: BatteryReading?) {
        self.next = next
    }

    func read() -> BatteryReading? {
        readCount += 1
        return next
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

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private func reading(percent: Double, at seconds: TimeInterval) -> BatteryReading {
    BatteryReading(
        snapshot: BatterySnapshot(
            timestamp: Date(timeIntervalSince1970: seconds),
            chargePercent: percent,
            chargeState: .discharging
        ))
}

@MainActor
@Suite struct BatteryMonitorTests {
    @Test func startReadsImmediatelyAndSubscribes() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        #expect(monitor.hasBattery == nil)

        monitor.start()
        #expect(monitor.isRunning)
        #expect(provider.readCount == 1)
        #expect(provider.handler != nil)
        #expect(monitor.snapshot?.chargePercent == 80)
        #expect(monitor.hasBattery == true)
    }

    @Test func systemChangeTriggersRefresh() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        monitor.start()

        provider.next = reading(percent: 79, at: 2)
        provider.simulateSystemChange()
        #expect(provider.readCount == 2)
        #expect(monitor.snapshot?.chargePercent == 79)
    }

    @Test func identicalStateKeepsOriginalSnapshot() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        monitor.start()

        provider.next = reading(percent: 80, at: 2)
        monitor.refresh()
        // Only the timestamp changed, so the snapshot (and the views reading it) stay put.
        #expect(monitor.snapshot?.timestamp == Date(timeIntervalSince1970: 1))
    }

    @Test func missingBatteryIsReported() {
        let provider = MockBatteryProvider(next: nil)
        let monitor = BatteryMonitor(provider: provider)
        monitor.start()
        #expect(monitor.hasBattery == false)
        #expect(monitor.snapshot == nil)
    }

    @Test func stopCancelsObservation() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        monitor.start()
        monitor.start()  // idempotent
        #expect(provider.readCount == 1)

        monitor.stop()
        #expect(!monitor.isRunning)
        #expect(provider.cancellations.value == 1)
    }

    @Test func liveRefreshPollsOnlyWhileEnabled() async throws {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        monitor.start()

        monitor.setLiveRefreshInterval(.milliseconds(5))
        try await Task.sleep(for: .milliseconds(200))
        #expect(provider.readCount >= 3)

        monitor.setLiveRefreshInterval(nil)
        let readsAfterDisabling = provider.readCount
        try await Task.sleep(for: .milliseconds(60))
        #expect(provider.readCount == readsAfterDisabling)
    }

    @Test func liveRefreshStopsWithMonitor() async throws {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        monitor.setLiveRefreshInterval(.milliseconds(5))
        // Not started yet: no polling.
        try await Task.sleep(for: .milliseconds(40))
        #expect(provider.readCount == 0)

        monitor.start()
        try await Task.sleep(for: .milliseconds(100))
        monitor.stop()
        let readsAtStop = provider.readCount
        #expect(readsAtStop >= 2)
        try await Task.sleep(for: .milliseconds(60))
        #expect(provider.readCount == readsAtStop)
    }
}

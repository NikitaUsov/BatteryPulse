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
        #expect(monitor.reading?.snapshot.timestamp == Date(timeIntervalSince1970: 1))
    }

    @Test func changedRawDataRepublishesReading() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        monitor.start()

        var next = reading(percent: 80, at: 2)
        next.smartBattery = ["UpdateTime": .int(2)]
        provider.next = next
        monitor.refresh()
        #expect(monitor.reading?.smartBattery["UpdateTime"] == .int(2))
        #expect(monitor.snapshot?.timestamp == Date(timeIntervalSince1970: 1))
    }

    @Test func overrideReplacesReadingsUntilCleared() {
        let device = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: device)
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
        device.simulateSystemChange()
        #expect(monitor.snapshot?.chargePercent == 79, "device notifications resume")
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

    @Test func shortestLiveRefreshRequestWins() {
        let provider = MockBatteryProvider(next: reading(percent: 80, at: 1))
        let monitor = BatteryMonitor(provider: provider)
        monitor.start()

        monitor.setLiveRefreshInterval(.seconds(15), for: "menuBar")
        monitor.setLiveRefreshInterval(.seconds(2), for: "popover")
        #expect(monitor.liveRefreshInterval == .seconds(2))
        // Opening a view refreshes right away instead of after the first interval.
        #expect(provider.readCount == 3)

        monitor.setLiveRefreshInterval(nil, for: "popover")
        #expect(monitor.liveRefreshInterval == .seconds(15))
        monitor.setLiveRefreshInterval(nil, for: "menuBar")
        #expect(monitor.liveRefreshInterval == nil)
        #expect(provider.readCount == 3)
        monitor.stop()
    }

    @Test func pluggingInIsFollowedByExtraReads() async throws {
        func reading(connected: Bool) -> BatteryReading {
            BatteryReading(
                snapshot: BatterySnapshot(
                    timestamp: Date(timeIntervalSince1970: 1), chargePercent: 50,
                    chargeState: connected ? .notCharging : .discharging, isExternalPowerConnected: connected))
        }
        let provider = MockBatteryProvider(next: reading(connected: false))
        let monitor = BatteryMonitor(provider: provider)
        monitor.powerChangeFollowUps = [.milliseconds(10), .milliseconds(20)]
        monitor.start()
        provider.simulateSystemChange()
        try await Task.sleep(for: .milliseconds(80))
        #expect(provider.readCount == 2, "no change of power source, no extra reads")

        provider.next = reading(connected: true)
        provider.simulateSystemChange()
        try await Task.sleep(for: .milliseconds(150))
        #expect(provider.readCount == 5)

        // Stopping cancels pending follow-ups.
        provider.next = reading(connected: false)
        monitor.powerChangeFollowUps = [.milliseconds(40)]
        provider.simulateSystemChange()
        monitor.stop()
        try await Task.sleep(for: .milliseconds(100))
        #expect(provider.readCount == 6)
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

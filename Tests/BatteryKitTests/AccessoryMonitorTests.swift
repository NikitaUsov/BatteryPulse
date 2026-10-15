import BatteryCore
import Foundation
import Observation
import Testing

@testable import BatteryKit

@MainActor
final class FakeAccessoryProvider: AccessoryProvider {
    var next: AccessoryReading?
    private(set) var readCount = 0
    private(set) var observeCount = 0
    private(set) var handler: (@MainActor @Sendable () -> Void)?
    let cancellations = Counter()

    init(next: AccessoryReading?) {
        self.next = next
    }

    func read() -> AccessoryReading? {
        readCount += 1
        return next
    }

    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        observeCount += 1
        self.handler = handler
        let cancellations = cancellations
        return BatteryObservation { cancellations.increment() }
    }

    func post() {
        handler?()
    }
}

/// One keyboard per percentage, named after its position.
private func reading(_ percents: [Int]) -> AccessoryReading {
    AccessoryReading(
        sources: percents.enumerated().map { index, percent in
            [
                "Name": .string("Keyboard \(index + 1)"), "Accessory Category": .string("Keyboard"),
                "Accessory Identifier": .string("id-\(index + 1)"), "Current Capacity": .int(Int64(percent)),
                "Power Source State": .string("Battery Power"),
            ]
        })
}

@MainActor
@Suite struct AccessoryMonitorTests {
    /// Waits until `condition` holds, for at most two seconds.
    private func wait(until condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func startReadsOnce() {
        let provider = FakeAccessoryProvider(next: reading([76, 18]))
        let monitor = AccessoryMonitor(provider: provider)
        #expect(monitor.isAvailable == nil)

        monitor.start()
        monitor.start()
        #expect(monitor.isRunning)
        #expect(provider.readCount == 1)
        #expect(provider.observeCount == 1)
        #expect(monitor.isAvailable == true)
        #expect(monitor.accessories.map(\.parts.first?.percent) == [76, 18])
    }

    @Test func unavailableProvider() {
        let none = AccessoryMonitor(provider: nil)
        none.start()
        #expect(none.isAvailable == false)
        #expect(none.accessories.isEmpty)

        let provider = FakeAccessoryProvider(next: reading([50]))
        let monitor = AccessoryMonitor(provider: provider)
        monitor.start()
        #expect(monitor.accessories.count == 1)
        provider.next = nil
        monitor.refresh()
        #expect(monitor.isAvailable == false)
        #expect(monitor.accessories.isEmpty)
    }

    @Test func emptyReadingIsAvailable() {
        let monitor = AccessoryMonitor(provider: FakeAccessoryProvider(next: reading([])))
        monitor.start()
        #expect(monitor.isAvailable == true)
        #expect(monitor.accessories.isEmpty)
    }

    @Test func identicalReadsDoNotReassign() {
        let provider = FakeAccessoryProvider(next: reading([76]))
        let monitor = AccessoryMonitor(provider: provider)
        monitor.start()

        let changes = Counter()
        withObservationTracking {
            _ = monitor.accessories
            _ = monitor.isAvailable
        } onChange: {
            changes.increment()
        }
        monitor.refresh()
        #expect(changes.value == 0)

        provider.next = reading([75])
        monitor.refresh()
        #expect(changes.value == 1)
        #expect(monitor.accessories.first?.parts.first?.percent == 75)
    }

    @Test func notificationBurstCoalesces() async {
        let provider = FakeAccessoryProvider(next: reading([76]))
        let monitor = AccessoryMonitor(provider: provider)
        monitor.coalescingDelay = .milliseconds(10)
        monitor.start()

        provider.next = reading([75])
        provider.post()
        provider.post()
        provider.post()
        #expect(provider.readCount == 1, "the read waits for the burst to end")
        await wait { provider.readCount == 2 }
        #expect(provider.readCount == 2)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(provider.readCount == 2)
        #expect(monitor.accessories.first?.parts.first?.percent == 75)

        provider.post()
        await wait { provider.readCount == 3 }
        #expect(provider.readCount == 3, "a later notification reads again")
    }

    @Test func refreshReplacesAPendingRead() async {
        let provider = FakeAccessoryProvider(next: reading([76]))
        let monitor = AccessoryMonitor(provider: provider)
        monitor.coalescingDelay = .milliseconds(10)
        monitor.start()

        provider.post()
        monitor.refresh()
        #expect(provider.readCount == 2)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(provider.readCount == 2)
    }

    @Test func overrideSwapsAndRestores() {
        let device = FakeAccessoryProvider(next: reading([76]))
        let demo = FakeAccessoryProvider(next: reading([10, 20, 30]))
        let monitor = AccessoryMonitor(provider: device)
        monitor.start()

        monitor.setOverride(demo)
        #expect(monitor.isOverridden)
        #expect(monitor.accessories.count == 3)
        #expect(device.cancellations.value == 1)
        #expect(demo.handler != nil)

        monitor.setOverride(nil)
        #expect(!monitor.isOverridden)
        #expect(monitor.accessories.count == 1)
        #expect(demo.cancellations.value == 1)
        #expect(device.observeCount == 2)
        #expect(device.readCount == 2)
    }

    @Test func demoProviderShowsTheDemoAccessories() {
        let monitor = AccessoryMonitor(provider: FakeAccessoryProvider(next: reading([76])))
        monitor.start()
        monitor.setOverride(DemoAccessoryProvider())
        #expect(monitor.accessories.map(\.name) == ["Magic Keyboard", "Magic Mouse", "AirPods Pro"])
        #expect(monitor.isAvailable == true)
    }

    @Test func overrideBeforeStartWaitsForStart() {
        let device = FakeAccessoryProvider(next: reading([76]))
        let demo = FakeAccessoryProvider(next: reading([10, 20]))
        let monitor = AccessoryMonitor(provider: device)
        monitor.setOverride(demo)
        #expect(monitor.isOverridden)
        #expect(demo.readCount == 0)

        monitor.start()
        #expect(monitor.accessories.count == 2)
        #expect(device.readCount == 0)
    }

    @Test func stopCancelsObservationAndPendingRead() async {
        let provider = FakeAccessoryProvider(next: reading([76]))
        let monitor = AccessoryMonitor(provider: provider)
        monitor.coalescingDelay = .milliseconds(10)
        monitor.start()

        provider.post()
        monitor.stop()
        #expect(!monitor.isRunning)
        #expect(provider.cancellations.value == 1)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(provider.readCount == 1)
    }
}

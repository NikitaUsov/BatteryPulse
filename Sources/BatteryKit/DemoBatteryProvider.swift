import BatteryCore
import BatterySource
import Foundation

/// Readings from a ``DemoBattery`` instead of the hardware, for Demo Mode.
@MainActor
public final class DemoBatteryProvider: BatteryProvider {
    /// The simulated state; `nil` simulates a Mac without a battery. Every change notifies the
    /// observer, so a ``BatteryMonitor`` showing this provider updates right away.
    public var battery: DemoBattery? {
        didSet {
            guard battery != oldValue else { return }
            for handler in handlers.values { handler() }
        }
    }

    /// When the simulated gauge last updated; kept steady so live views don't churn.
    public var gaugeUpdatedAt = Date()

    private var handlers: [Int: @MainActor @Sendable () -> Void] = [:]
    private var nextHandlerID = 0

    public init(battery: DemoBattery? = nil) {
        self.battery = battery
    }

    public func read() -> BatteryReading? {
        battery?.reading(at: Date(), gaugeUpdatedAt: gaugeUpdatedAt)
    }

    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        let id = nextHandlerID
        nextHandlerID += 1
        handlers[id] = handler
        return BatteryObservation { [weak self] in
            Task { @MainActor in self?.handlers[id] = nil }
        }
    }
}

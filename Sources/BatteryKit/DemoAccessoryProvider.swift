import BatteryCore

/// Demo Mode's fixed accessories (``DemoAccessories``) instead of the connected ones.
@MainActor
public final class DemoAccessoryProvider: AccessoryProvider {
    public init() {}

    public func read() -> AccessoryReading? {
        AccessoryReading(sources: DemoAccessories.sources)
    }

    /// The demo accessories never change.
    public func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation {
        BatteryObservation {}
    }
}

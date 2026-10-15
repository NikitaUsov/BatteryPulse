import BatteryCore

/// A source of accessory battery readings (Bluetooth keyboards, mice, trackpads, headphones).
@MainActor
public protocol AccessoryProvider: AnyObject {
    /// `nil` when this system doesn't publish accessory batteries; a reading with no
    /// accessories when none are connected.
    func read() -> AccessoryReading?

    /// Calls `handler` on the main actor when the system signals an accessory change. Delivery
    /// stops when the returned observation is cancelled or deallocated.
    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation
}

public enum SystemAccessories {
    /// The provider for this platform, or `nil` where accessory batteries aren't published
    /// (Linux, iOS).
    @MainActor
    public static func makeProvider() -> (any AccessoryProvider)? {
        #if os(macOS)
        MacAccessoryProvider()
        #else
        nil
        #endif
    }
}

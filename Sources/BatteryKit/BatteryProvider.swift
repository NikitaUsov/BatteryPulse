import BatteryCore

/// A source of battery readings for the current device.
@MainActor
public protocol BatteryProvider: AnyObject {
    /// Reads the current state in full, or `nil` when the device has no battery
    /// (desktop Mac, CI virtual machine, iOS Simulator).
    func read() -> BatteryReading?

    /// Reads the current state; `.live` lets the provider reuse what an earlier read fetched of
    /// the values that change slowly. A provider without such values reads in full (the default).
    func read(scope: BatteryReadScope) -> BatteryReading?

    /// What reads this battery off the main actor, for a caller that keeps its reads off it, such
    /// as ``BatteryMonitor``. `nil`, the default, keeps every read on the main actor, as Demo Mode's
    /// simulated battery and `UIDevice` need.
    var nonisolatedReader: (any NonisolatedBatteryReader)? { get }

    /// Calls `handler` on the main actor whenever the OS signals a power-related change.
    /// Delivery stops when the returned observation is cancelled or deallocated.
    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> BatteryObservation
}

extension BatteryProvider {
    public func read(scope: BatteryReadScope) -> BatteryReading? {
        read()
    }

    public var nonisolatedReader: (any NonisolatedBatteryReader)? {
        nil
    }
}

/// A battery read that may run on any thread, and so off the main actor. A synchronous read
/// satisfies the requirement, as `MacBatteryProvider`'s does.
public protocol NonisolatedBatteryReader: Sendable {
    /// Reads like ``BatteryProvider/read(scope:)``, on the caller's executor.
    func readNonisolated(scope: BatteryReadScope) async -> BatteryReading?
}

/// What a battery read fetches again.
public enum BatteryReadScope: Sendable {
    /// Everything, as ``BatteryProvider/read()`` does: on a Mac, every SMC key.
    case full
    /// What polls exist for: on a Mac, the SMC's live voltage and current. The slow values, such
    /// as the SMC's cell voltages and temperatures, may come from an earlier read.
    case live
}

/// Keeps a change subscription alive; cancels it on `cancel()` or deinit.
public final class BatteryObservation {
    private var onCancel: (@Sendable () -> Void)?

    public init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit {
        onCancel?()
    }
}

public enum SystemBattery {
    /// The provider for the platform this code runs on, or `nil` where none exists (Linux).
    @MainActor
    public static func makeProvider() -> (any BatteryProvider)? {
        #if os(macOS)
        MacBatteryProvider()
        #elseif os(iOS)
        IOSBatteryProvider()
        #else
        nil
        #endif
    }
}

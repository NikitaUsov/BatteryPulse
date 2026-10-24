import BatteryCore

/// A source of battery readings for the current device.
@MainActor
public protocol BatteryProvider: AnyObject {
    /// Reads the current state in full, or `nil` when the device has no battery
    /// (desktop Mac, CI virtual machine, iOS Simulator).
    func read() -> BatteryReading?

    /// Reads the current state; a scope other than `.full` lets the provider reuse what an earlier
    /// read fetched of the values that change slowly. A provider without such values reads in full
    /// (the default).
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

/// What a battery read fetches again, as two independent decisions: the registry
/// (``RegistryReadPolicy``) and the SMC's slow keys (``SMCReadPolicy``). A provider may reuse what
/// an earlier read fetched of what the scope leaves out; one without such values reads in full.
public struct BatteryReadScope: Sendable, Hashable {
    /// Whether the read fetches the registry again: on a Mac, `AppleSmartBattery` and its
    /// children, and the power-source and adapter dictionaries. `false` lets the provider reuse
    /// an earlier read's, once one has fetched them.
    public var rereadsRegistry: Bool
    /// Whether the read asks the SMC for every key. `false` asks only for the live voltage and
    /// current, and the slow values, such as the SMC's cell voltages and temperatures, may come
    /// from an earlier read.
    public var readsAllSMCKeys: Bool

    public init(rereadsRegistry: Bool, readsAllSMCKeys: Bool) {
        self.rereadsRegistry = rereadsRegistry
        self.readsAllSMCKeys = readsAllSMCKeys
    }

    /// Everything, as ``BatteryProvider/read()`` does: the registry and every SMC key.
    public static let full = BatteryReadScope(rereadsRegistry: true, readsAllSMCKeys: true)
    /// The registry and the SMC's live pair.
    public static let live = BatteryReadScope(rereadsRegistry: true, readsAllSMCKeys: false)
    /// What polls exist for: the SMC's live pair, beside an earlier read's registry.
    public static let cached = BatteryReadScope(rereadsRegistry: false, readsAllSMCKeys: false)
    /// Every SMC key beside an earlier read's registry: a poll when the slow values are due.
    public static let cachedSlow = BatteryReadScope(rereadsRegistry: false, readsAllSMCKeys: true)

    /// The `read` signpost's trigger (``Signposts``): `full`, `live`, `cached` or `cached.slow`.
    public var signpostName: StaticString {
        switch (rereadsRegistry, readsAllSMCKeys) {
        case (true, true): "full"
        case (true, false): "live"
        case (false, false): "cached"
        case (false, true): "cached.slow"
        }
    }
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

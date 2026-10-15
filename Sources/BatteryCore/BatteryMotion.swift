import Foundation

/// How much a window animates: the app's single gate for motion.
///
/// Every animation in the app goes through it (`\.motion` in the app's environment), so Reduce
/// Motion turns movement into fades and a window nobody can see animates nothing. The inputs are
/// set per window; the app maps ``level`` to concrete animations and transitions.
public struct MotionPolicy: Sendable, Equatable {
    public enum Level: Sendable, Equatable, CaseIterable {
        /// Nothing animates: the window can't be seen.
        case none
        /// Fades only: no movement, scale, blur or bounce (Reduce Motion).
        case fade
        /// Everything, kept short and played once.
        case full
    }

    /// The Reduce Motion accessibility setting.
    public var reduceMotion: Bool
    /// "Prefer cross-fade transitions"; on macOS it follows Reduce Motion.
    public var prefersCrossFade: Bool
    /// Whether any part of the window is on screen (its occlusion state).
    public var isVisible: Bool
    /// Low Power Mode, or the system asking apps to scale back resource-intensive work.
    public var reducesResources: Bool

    public init(
        reduceMotion: Bool = false,
        prefersCrossFade: Bool = false,
        isVisible: Bool = true,
        reducesResources: Bool = false
    ) {
        self.reduceMotion = reduceMotion
        self.prefersCrossFade = prefersCrossFade
        self.isVisible = isVisible
        self.reducesResources = reducesResources
    }

    public var level: Level {
        guard isVisible else { return .none }
        return reduceMotion || prefersCrossFade ? .fade : .full
    }

    /// One-off extras that only decorate (a bounce, a staggered entrance, a line drawing in).
    /// Functional transitions stay under Low Power Mode; these go.
    public var allowsFlourish: Bool {
        level == .full && !reducesResources
    }
}

/// The discrete parts of a snapshot that animations key on.
///
/// A live reading every 2 s changes the snapshot almost every time (power, voltage, current,
/// temperature, time estimates), so nothing animates on the snapshot itself. This key changes
/// only on battery events: the whole percent, the level tier, plugging in or out, the charge
/// state, the battery symbol, the direction of the battery's power flow and Low Power Mode.
public struct BatteryMotionKey: Sendable, Hashable {
    /// Which way power moves through the battery, with the dead band the power-flow label uses.
    public enum Flow: Sendable, Hashable {
        case intoBattery, outOfBattery, idle

        /// `nil` (no reading) and anything inside ``BatteryPresentation/powerFlowDeadBandWatts``
        /// are idle.
        public init(batteryWatts: Double?) {
            guard let watts = batteryWatts, abs(watts) >= BatteryPresentation.powerFlowDeadBandWatts else {
                self = .idle
                return
            }
            self = watts > 0 ? .intoBattery : .outOfBattery
        }
    }

    /// The charge rounded to a whole percent, as the app shows it.
    public var percent: Int?
    public var tier: BatteryPresentation.LevelTier
    /// External power is connected.
    public var isPluggedIn: Bool
    /// `nil` only without a snapshot.
    public var chargeState: ChargeState?
    /// ``BatteryPresentation/symbolName(for:)``: changes at 13, 38, 63 and 88 % and when charging
    /// starts or stops.
    public var symbolName: String
    public var flow: Flow
    /// Low Power Mode as the snapshot reports it (a Demo Mode scene can simulate it). The app's
    /// own motion follows the real setting through ``MotionPolicy/reducesResources``.
    public var isLowPowerMode: Bool

    /// A missing snapshot (before the first reading, or no battery) gives a key of its own.
    public init(_ snapshot: BatterySnapshot?) {
        // `.toNearestOrEven` is how the formatter rounds a percentage without decimals.
        percent = snapshot?.chargePercent.map { Int($0.rounded(.toNearestOrEven)) }
        tier = snapshot.map(BatteryPresentation.levelTier(for:)) ?? .normal
        isPluggedIn = snapshot?.isExternalPowerConnected == true
        chargeState = snapshot?.chargeState
        symbolName = BatteryPresentation.symbolName(for: snapshot)
        flow = Flow(batteryWatts: snapshot?.batteryPowerWatts)
        isLowPowerMode = snapshot?.isLowPowerModeEnabled == true
    }
}

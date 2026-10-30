import Foundation

/// When the app asks WidgetKit to reload each widget kind. WidgetKit gives each placed widget a
/// daily budget of about 40–70 reloads, and the app is rarely in front, so every reload it asks
/// for counts; the widgets refresh their own timelines every 30 minutes in between.
///
/// - **Battery:** ``WidgetReloadPolicy``, 0.6.x's rules for plug and state changes, the first
///   estimate, a 3-point step and a moved estimate. Four more reasons reload at once: a Low Power
///   Mode flip, a change of the adapter's watts or wireless flag, a change of condition, and the
///   thermal state entering serious or critical. The thermal reason has the heat alert's
///   hysteresis: leaving reloads only once the state is back at nominal, so a state flapping
///   between fair and serious under load reloads once. These four share ``immediateInterval``
///   between their reloads. A temperature move of ``temperatureStep`` waits, like a percent step,
///   until ``WidgetReloadPolicy/minimumInterval`` has passed since the kind's last reload.
/// - **Accessories:** a connect or a disconnect reloads at once. A step of ``accessoryStep``
///   points waits until ``accessoryInterval`` has passed since the kind's last reload.
///
/// The app never reads a placed widget's configuration, so one plan serves every configuration
/// and accepts the odd reload a widget doesn't need. Each kind's first evaluation is the value the
/// app finds at its start, which the widget shows already as far as the app can tell: it is
/// recorded without a reload. A reload is recorded when it is decided; ``WidgetPlacements`` then
/// says whether the kind is placed at all.
public struct WidgetReloadPlanner: Sendable {
    /// The least time between two reloads for a Low Power Mode flip, the adapter, the condition or
    /// the heat.
    static let immediateInterval: TimeInterval = 5 * 60
    /// In °C.
    static let temperatureStep = 3.0
    /// In percentage points of any part of any accessory.
    static let accessoryStep = 10
    static let accessoryInterval: TimeInterval = 15 * 60

    /// Why a kind reloads; logged as its case name.
    public enum Reason: String, Sendable, CaseIterable {
        /// ``WidgetReloadPolicy``: a plug or state change, the first estimate, a 3-point step or a
        /// moved estimate.
        case policy
        case lowPowerMode
        /// The adapter's watts or wireless flag.
        case adapter
        case condition
        /// The thermal state entered serious or critical, or came back to nominal.
        case heat
        case temperature
        /// An accessory connected or disconnected.
        case connection
        /// A part of an accessory moved ``WidgetReloadPlanner/accessoryStep`` points.
        case level
    }

    /// What the Battery widget shows besides ``WidgetReloadPolicy``'s values, as of its last reload.
    private struct BatteryShown: Sendable {
        var isLowPowerModeEnabled: Bool
        var adapterWatts: Int?
        var adapterIsWireless: Bool?
        var condition: WidgetCondition
        /// Serious or critical; fair keeps the previous answer, so only nominal ends it.
        var isHot: Bool
        var temperature: Double?

        /// `previous` carries the heat across fair and an unknown state.
        init(_ snapshot: BatterySnapshot, previous: BatteryShown?) {
            isLowPowerModeEnabled = snapshot.isLowPowerModeEnabled ?? false
            adapterWatts = snapshot.adapter?.watts
            adapterIsWireless = snapshot.adapter?.isWireless
            condition = WidgetCondition(snapshot.healthCondition)
            isHot =
                switch snapshot.thermalState {
                case .serious?, .critical?: true
                case .nominal?: false
                case .fair?, nil: previous?.isHot ?? false
                }
            temperature = snapshot.temperatureCelsius
        }

        /// The first reason to reload at once on the way to `next`.
        func immediateReason(to next: BatteryShown) -> Reason? {
            if next.isLowPowerModeEnabled != isLowPowerModeEnabled { return .lowPowerMode }
            if next.adapterWatts != adapterWatts || next.adapterIsWireless != adapterIsWireless { return .adapter }
            if next.condition != condition { return .condition }
            if next.isHot != isHot { return .heat }
            return nil
        }

        func temperatureMoved(to next: BatteryShown) -> Bool {
            guard let temperature, let nextTemperature = next.temperature else { return false }
            return abs(nextTemperature - temperature) >= WidgetReloadPlanner.temperatureStep
        }
    }

    /// Each accessory's parts and their percentages, by the accessory's ID, as of the kind's last
    /// reload.
    private struct AccessoriesShown: Sendable {
        var levels: [String: [AccessoryPartRole: Int]]

        init(_ accessories: [AccessoryBattery]) {
            levels = Dictionary(
                accessories.map { accessory in
                    (accessory.id, Dictionary(accessory.parts.map { ($0.role, $0.percent) }, uniquingKeysWith: min))
                },
                uniquingKeysWith: { first, _ in first })
        }

        func connectionChanged(to next: AccessoriesShown) -> Bool {
            Set(next.levels.keys) != Set(levels.keys)
        }

        /// A part both have moved ``WidgetReloadPlanner/accessoryStep`` points.
        func stepped(to next: AccessoriesShown) -> Bool {
            next.levels.contains { id, parts in
                guard let shownParts = levels[id] else { return false }
                return parts.contains { role, percent in
                    shownParts[role].map { abs(percent - $0) >= WidgetReloadPlanner.accessoryStep } ?? false
                }
            }
        }
    }

    private var policy = WidgetReloadPolicy()
    private var batteryShown: BatteryShown?
    private var lastBatteryReload: Date?
    private var lastImmediateReload: Date?
    private var accessoriesShown: AccessoriesShown?
    private var lastAccessoryReload: Date?

    public init() {}

    /// Why the Battery kind reloads for `snapshot` now, or `nil` when it waits; records the reload.
    /// The first evaluation records `snapshot` and returns `nil`.
    public mutating func battery(_ snapshot: BatterySnapshot, at date: Date) -> Reason? {
        guard let shown = batteryShown else {
            policy.record(snapshot, at: date, reloaded: false)
            batteryShown = BatteryShown(snapshot, previous: nil)
            return nil
        }
        let next = BatteryShown(snapshot, previous: shown)
        let reason: Reason
        if policy.shouldReload(for: snapshot, at: date) {
            reason = .policy
        } else if let immediate = shown.immediateReason(to: next),
            Self.hasPassed(Self.immediateInterval, since: lastImmediateReload, at: date)
        {
            reason = immediate
            lastImmediateReload = date
            policy.record(snapshot, at: date)
        } else if shown.temperatureMoved(to: next),
            Self.hasPassed(WidgetReloadPolicy.minimumInterval, since: lastBatteryReload, at: date)
        {
            reason = .temperature
            policy.record(snapshot, at: date)
        } else {
            return nil
        }
        batteryShown = next
        lastBatteryReload = date
        return reason
    }

    /// Why the Accessories kind reloads for `accessories` now, or `nil` when it waits; records the
    /// reload. The first evaluation records `accessories` and returns `nil`.
    public mutating func accessories(_ accessories: [AccessoryBattery], at date: Date) -> Reason? {
        let next = AccessoriesShown(accessories)
        guard let shown = accessoriesShown else {
            accessoriesShown = next
            return nil
        }
        let reason: Reason
        if shown.connectionChanged(to: next) {
            reason = .connection
        } else if shown.stepped(to: next), Self.hasPassed(Self.accessoryInterval, since: lastAccessoryReload, at: date)
        {
            reason = .level
        } else {
            return nil
        }
        accessoriesShown = next
        lastAccessoryReload = date
        return reason
    }

    /// Whether `interval` has passed since `last`; with no `last`, or a clock set back before it,
    /// it has.
    private static func hasPassed(_ interval: TimeInterval, since last: Date?, at date: Date) -> Bool {
        guard let last, date >= last else { return true }
        return date.timeIntervalSince(last) >= interval
    }
}

// MARK: Launch

extension WidgetReloadPlanner {
    /// Why a launch ends the widget extension and reloads.
    public enum LaunchReason: String, Sendable {
        /// Another version runs: WidgetKit refuses the timelines of the previous version's
        /// extension while it still runs, so it is ended, and every kind reloads if it was running.
        case update
        /// The app's language changed since its last launch: every placed widget keeps the
        /// previous language's render until it reloads, so the extension is ended and every kind
        /// reloads, whether it was running or not.
        case language

        /// Whether every kind reloads even when no extension was running.
        public var reloadsAnyway: Bool { self == .language }
    }

    /// Why this launch ends the widget extension and reloads, or `nil`. `language` is the app's
    /// effective language now (its first preferred localization) and `lastLanguage` the one it
    /// stored at its last launch; without either, as at the first launch that stores one, only the
    /// version decides. A changed language includes what a changed version does.
    public static func launchReason(versionChanged: Bool, lastLanguage: String?, language: String?) -> LaunchReason? {
        if let lastLanguage, let language, lastLanguage != language { return .language }
        return versionChanged ? .update : nil
    }
}

// MARK: Placements

/// Which widget kinds someone placed, from WidgetKit's last answer to `currentConfigurations()`,
/// kept in memory. A kind is skipped only when a non-empty answer leaves it out: no answer yet, a
/// failure and an empty answer count as every kind placed, because whether WidgetKit answers this
/// ad-hoc-signed app with its real placements is unverified, and a silently empty answer would
/// otherwise stop every reload the app asks for.
///
/// The answer is asked for only at a reload moment, never on a schedule of its own: before the
/// first reload, and again when the answer would skip the kind that is due and is
/// ``maximumAge`` old, so a widget placed since is reloaded within that time while the app runs.
public struct WidgetPlacements: Sendable {
    static let maximumAge: TimeInterval = 15 * 60

    /// The kind strings of the last non-empty answer; `nil` for every kind placed.
    private var placed: Set<String>?
    private var answeredAt: Date?

    public init() {}

    /// Records WidgetKit's answer: the kind string of every placed widget, one per widget.
    public mutating func record(answer kinds: [String], at date: Date) {
        placed = kinds.isEmpty ? nil : Set(kinds)
        answeredAt = date
    }

    /// Records a failed answer, which counts as every kind placed.
    public mutating func recordFailure(at date: Date) {
        placed = nil
        answeredAt = date
    }

    public func isPlaced(_ kind: WidgetKindID) -> Bool {
        placed?.contains(kind.rawValue) ?? true
    }

    /// Whether to ask WidgetKit before reloading `kind` at `date`.
    public func needsAnswer(toReload kind: WidgetKindID, at date: Date) -> Bool {
        guard let answeredAt else { return true }
        guard !isPlaced(kind) else { return false }
        // A clock set back before the answer can't tell its age.
        return date < answeredAt || date.timeIntervalSince(answeredAt) >= Self.maximumAge
    }

    /// How many widgets of each kind an answer lists, every kind included; kind strings this
    /// version doesn't know don't count.
    public static func counts(in kinds: [String]) -> [WidgetKindID: Int] {
        Dictionary(
            uniqueKeysWithValues: WidgetKindID.allCases.map { kind in
                (kind, kinds.count(where: { $0 == kind.rawValue }))
            })
    }
}

import Foundation

/// When the app asks WidgetKit to reload each widget kind. WidgetKit gives each placed widget a
/// daily budget of about 40–70 reloads, and the app is rarely in front, so every reload it asks
/// for counts; the widgets refresh their own timelines every 30 minutes in between.
///
/// - **Battery:** ``WidgetReloadPolicy``, 0.6.x's rules for plug and state changes, the first
///   estimate, a 3-point step and a moved estimate. Five more reasons reload at once: a Low Power
///   Mode flip, a change of the adapter's watts or wireless flag, a change of condition, the
///   thermal state entering serious or critical, and the Charge Limit's hold starting or ending
///   without a change of the charge state, or its number changing, which the Charge limit field
///   shows once the app has written it to the feed. The thermal reason has the heat alert's
///   hysteresis: leaving reloads only once the state is back at nominal, so a state flapping
///   between fair and serious under load reloads once. These five share ``immediateInterval``
///   between their reloads. A temperature move of ``temperatureStep`` waits, like a percent step,
///   until ``WidgetReloadPolicy/minimumInterval`` has passed since the kind's last reload.
/// - **Accessories:** a connect or a disconnect reloads at once. A step of ``accessoryStep``
///   points waits until ``accessoryInterval`` has passed since the kind's last reload.
/// - **History:** a plug change, the charging stretches its chart shades, at most once per
///   ``historyInterval``; a change that waited reloads once the interval has passed, if the plug
///   still differs from what the kind last showed. Its timeline refreshes hourly in between
///   (``WidgetTimelinePlan/history(writtenAt:at:)``).
/// - **iPhone & iPad:** a new reading that moved a device's charge ``deviceStep`` points, changed
///   its state or read a device for the first time, at most once per ``devicesInterval``; a
///   change that waited reloads once the interval has passed. Its timeline refreshes every half
///   hour in between (``WidgetTimelinePlan/devices(writtenAt:at:timeZone:)``).
/// - **A removal:** Clear History, Record battery history turned off, Read iPhone and iPad
///   batteries turned off and Forget rewrite the feed without what they remove, and the kinds that
///   show it then reload at once (``removal(of:at:)``), so a placed widget doesn't keep showing it
///   until its own timeline's reload: within each kind's immediate reasons' shared minimum,
///   ``immediateInterval``, the Battery kind's shared with its five above. A removal that waits
///   reloads at the first evaluation after the minimum (``pendingReloads(at:)``), never on a
///   timer of its own.
/// - **A repair or an addition:** a write that replaced a feed the widgets couldn't use or that
///   had aged (``WidgetFeed/Repair``), or that added a section they show (Record battery history
///   or device reads turned on, a kind newly placed), reloads the kinds that show it the same way
///   (``written(_:at:)``): so "Open BatteryPulse to update", or a state that waits for the
///   section, goes soon after BatteryPulse writes, not at the kind's own hourly or half-hourly
///   refresh.
///
/// The app never reads a placed widget's configuration, so one plan serves every configuration
/// and accepts the odd reload a widget doesn't need. Each kind's first evaluation is the value the
/// app finds at its start, which the widget shows already as far as the app can tell: it is
/// recorded without a reload. A reload is recorded when it is decided; ``WidgetPlacements`` then
/// says whether the kind is placed at all.
public struct WidgetReloadPlanner: Sendable {
    /// The least time between two reloads for a Low Power Mode flip, the adapter, the condition,
    /// the heat or the Charge Limit's hold.
    static let immediateInterval: TimeInterval = 5 * 60
    /// In °C.
    static let temperatureStep = 3.0
    /// In percentage points of any part of any accessory.
    static let accessoryStep = 10
    static let accessoryInterval: TimeInterval = 15 * 60
    /// The least time between two reloads of the History kind.
    static let historyInterval: TimeInterval = 60 * 60
    /// In percentage points of any iPhone's or iPad's charge.
    static let deviceStep = 3
    /// The least time between two reloads of the iPhone & iPad kind for a new reading.
    static let devicesInterval: TimeInterval = 15 * 60

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
        /// macOS's Charge Limit started or stopped holding the charge
        /// (``BatterySnapshot/isAtSystemChargeLimit``) with no change of the charge state, which
        /// ``WidgetReloadPolicy`` reloads for: plugged in near the limit, the state goes from
        /// discharging to not charging first, and the hold's bit may follow. Or its number changed
        /// (``BatterySnapshot/systemChargeLimitPercent``), which the app writes to the feed first.
        case systemChargeLimit
        case temperature
        /// An accessory connected or disconnected.
        case connection
        /// A part of an accessory moved ``WidgetReloadPlanner/accessoryStep`` points.
        case level
        /// The adapter was plugged in or out: the History kind's charging stretches.
        case plug
        /// An iPhone or iPad was read for the first time, or its charge moved
        /// ``WidgetReloadPlanner/deviceStep`` points, or its state changed.
        case reading
        /// The feed was rewritten without what the user removed, which the kind shows: the
        /// history (Clear History, recording off) or the devices (reads off, Forget).
        case removal
        /// The feed was written in place of one the widgets couldn't use or that had aged
        /// (``WidgetFeed/Repair``).
        case repair
        /// The feed was written with a section the kind shows that the one before left out
        /// (``WidgetFeed/WriteEffect/added``).
        case addition
    }

    /// A kind to reload now, and why: a change of the feed it shows (``Reason/removal``,
    /// ``Reason/repair`` or ``Reason/addition``).
    public struct FeedReload: Sendable, Equatable {
        public var kind: WidgetKindID
        public var reason: Reason

        public init(_ kind: WidgetKindID, _ reason: Reason) {
            self.kind = kind
            self.reason = reason
        }
    }

    /// What the Battery widget shows besides ``WidgetReloadPolicy``'s values, as of its last reload.
    private struct BatteryShown: Sendable {
        var isLowPowerModeEnabled: Bool
        var adapterWatts: Int?
        var adapterIsWireless: Bool?
        var condition: WidgetCondition
        /// The planner's heat as of the reload.
        var isHot: Bool
        var isAtSystemChargeLimit: Bool
        var systemChargeLimitPercent: Int?
        var temperature: Double?

        init(_ snapshot: BatterySnapshot, isHot: Bool) {
            isLowPowerModeEnabled = snapshot.isLowPowerModeEnabled ?? false
            adapterWatts = snapshot.adapter?.watts
            adapterIsWireless = snapshot.adapter?.isWireless
            condition = WidgetCondition(snapshot.healthCondition)
            self.isHot = isHot
            isAtSystemChargeLimit = snapshot.isAtSystemChargeLimit
            systemChargeLimitPercent = snapshot.systemChargeLimitPercent
            temperature = snapshot.temperatureCelsius
        }

        /// The first reason to reload at once on the way to `next`.
        func immediateReason(to next: BatteryShown) -> Reason? {
            if next.isLowPowerModeEnabled != isLowPowerModeEnabled { return .lowPowerMode }
            if next.adapterWatts != adapterWatts || next.adapterIsWireless != adapterIsWireless { return .adapter }
            if next.condition != condition { return .condition }
            if next.isHot != isHot { return .heat }
            if next.isAtSystemChargeLimit != isAtSystemChargeLimit
                || next.systemChargeLimitPercent != systemChargeLimitPercent
            {
                return .systemChargeLimit
            }
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

    /// Each real device's charge and state, by its key, as of the iPhone & iPad kind's last
    /// reload.
    private struct DevicesShown: Sendable {
        struct Reading: Sendable, Equatable {
            var percent: Int?
            var state: ChargeState
        }

        var readings: [DeviceKey: Reading]

        init(_ devices: [RememberedDevice]) {
            readings = Dictionary(
                devices.filter { $0.id != .demo }.map { device in
                    let percent = device.battery?.chargePercent.flatMap { $0.isFinite ? Int($0.rounded()) : nil }
                    return (device.id, Reading(percent: percent, state: device.battery?.chargeState ?? .unknown))
                },
                uniquingKeysWith: { first, _ in first })
        }

        /// A device read for the first time, or one both have whose charge moved
        /// ``WidgetReloadPlanner/deviceStep`` points or whose state changed.
        func moved(to next: DevicesShown) -> Bool {
            next.readings.contains { key, reading in
                guard let shown = readings[key] else { return true }
                if reading.state != shown.state { return true }
                guard let percent = reading.percent, let shownPercent = shown.percent else {
                    return (reading.percent == nil) != (shown.percent == nil)
                }
                return abs(percent - shownPercent) >= WidgetReloadPlanner.deviceStep
            }
        }
    }

    private var policy = WidgetReloadPolicy()
    private var batteryShown: BatteryShown?
    /// Whether the Mac runs hot, with the heat alert's hysteresis over every evaluation, reloaded
    /// or not: serious or critical turn it on, only nominal turns it off, and fair or an unknown
    /// state keep it. So a change that waited out ``immediateInterval`` still reloads afterwards.
    private var isHot = false
    private var lastBatteryReload: Date?
    private var lastImmediateReload: Date?
    private var accessoriesShown: AccessoriesShown?
    private var lastAccessoryReload: Date?
    /// Whether the History kind last showed the Mac on its adapter; `nil` before a reading that
    /// says.
    private var historyPlugged: Bool?
    private var historyStarted = false
    private var lastHistoryReload: Date?
    private var devicesShown: DevicesShown?
    private var lastDevicesReload: Date?
    /// The kinds a change of the feed reloads that wait for their kind's minimum, each with the
    /// reason it first waited for.
    private var pendingFeedReloads: [WidgetKindID: Reason] = [:]
    /// The last immediate reload of the Accessories, History and iPhone & iPad kinds, for a change
    /// of the feed; the Battery kind's is ``lastImmediateReload``.
    private var lastImmediateReloads: [WidgetKindID: Date] = [:]

    public init() {}

    /// Why the Battery kind reloads for `snapshot` now, or `nil` when it waits; records the reload.
    /// The first evaluation records `snapshot` and returns `nil`.
    public mutating func battery(_ snapshot: BatterySnapshot, at date: Date) -> Reason? {
        isHot =
            switch snapshot.thermalState {
            case .serious?, .critical?: true
            case .nominal?: false
            case .fair?, nil: isHot
            }
        let next = BatteryShown(snapshot, isHot: isHot)
        guard let shown = batteryShown else {
            policy.record(snapshot, at: date, reloaded: false)
            batteryShown = next
            return nil
        }
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

    /// Why the History kind reloads for `snapshot` now, or `nil` when it waits; records the
    /// reload. The first evaluation records `snapshot` and returns `nil`, and a reading that
    /// doesn't say whether the adapter is connected changes nothing.
    public mutating func history(_ snapshot: BatterySnapshot, at date: Date) -> Reason? {
        let plugged = snapshot.isExternalPowerConnected
        guard historyStarted else {
            historyStarted = true
            historyPlugged = plugged
            return nil
        }
        guard let plugged else { return nil }
        guard let shown = historyPlugged else {
            historyPlugged = plugged
            return nil
        }
        guard plugged != shown, Self.hasPassed(Self.historyInterval, since: lastHistoryReload, at: date) else {
            return nil
        }
        historyPlugged = plugged
        lastHistoryReload = date
        return .plug
    }

    /// Why the iPhone & iPad kind reloads for the remembered `devices` now, or `nil` when it
    /// waits; records the reload. The first evaluation records `devices` and returns `nil`, Demo
    /// Mode's device never counts, and a device no longer remembered only leaves the record:
    /// Forget reloads through the removal that rewrites the feed.
    public mutating func devices(_ devices: [RememberedDevice], at date: Date) -> Reason? {
        let next = DevicesShown(devices)
        guard var shown = devicesShown else {
            devicesShown = next
            return nil
        }
        shown.readings = shown.readings.filter { next.readings[$0.key] != nil }
        guard shown.moved(to: next), Self.hasPassed(Self.devicesInterval, since: lastDevicesReload, at: date) else {
            devicesShown = shown
            return nil
        }
        devicesShown = next
        lastDevicesReload = date
        return .reading
    }

    /// The kinds that show `section` (``WidgetFeed/Section/readers``) to reload with
    /// ``Reason/removal`` now that a removal rewrote the feed without it, each at once unless its
    /// kind reloaded for an immediate reason less than ``immediateInterval`` ago; those wait for
    /// ``pendingReloads(at:)``. Records the reloads. Demo Mode included: the rewrite took out only
    /// what the user removed, and no widget shows the demo.
    public mutating func removal(of section: WidgetFeed.Section, at date: Date) -> [FeedReload] {
        wait(section.readers, for: .removal)
        return pendingReloads(at: date)
    }

    /// The kinds that show what a write of the feed changed (``WidgetFeed/WriteEffect``) to
    /// reload now, as ``removal(of:at:)``'s do: with ``Reason/repair`` those that show the feed it
    /// replaced (``WidgetFeed/Repair/readers``), and with ``Reason/addition`` those that show a
    /// section it added. Records the reloads; none for ``WidgetFeed/WriteEffect/nothing``.
    public mutating func written(_ effect: WidgetFeed.WriteEffect, at date: Date) -> [FeedReload] {
        if let repair = effect.repair { wait(repair.readers, for: .repair) }
        for section in WidgetFeed.Section.allCases where effect.added.contains(section) {
            wait(section.readers, for: .addition)
        }
        return pendingReloads(at: date)
    }

    /// Adds `kinds` to the reloads that wait; a kind that waits already keeps its first reason.
    private mutating func wait(_ kinds: [WidgetKindID], for reason: Reason) {
        for kind in kinds where pendingFeedReloads[kind] == nil {
            pendingFeedReloads[kind] = reason
        }
    }

    /// The kinds whose reload for a change of the feed waited and may reload now, in
    /// ``WidgetKindID``'s order; records the reloads. The app asks at every evaluation, so a reload
    /// that waited comes at the first one after its minimum, never on a timer of its own.
    public mutating func pendingReloads(at date: Date) -> [FeedReload] {
        let due = WidgetKindID.allCases.compactMap { kind in
            pendingFeedReloads[kind].flatMap { reason in
                Self.hasPassed(Self.immediateInterval, since: lastImmediate(kind), at: date)
                    ? FeedReload(kind, reason) : nil
            }
        }
        for reload in due {
            pendingFeedReloads[reload.kind] = nil
            if reload.kind == .battery {
                lastImmediateReload = date
                lastBatteryReload = date
            } else {
                lastImmediateReloads[reload.kind] = date
            }
        }
        return due
    }

    /// When `kind` last reloaded for an immediate reason.
    private func lastImmediate(_ kind: WidgetKindID) -> Date? {
        kind == .battery ? lastImmediateReload : lastImmediateReloads[kind]
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

        /// What the launch does, in this order. A language change writes the widget feed first
        /// and waits for it: the widgets take BatteryPulse's language from it
        /// (``WidgetLanguage``), so the extension the reload starts must find the new one, and a
        /// running one must not keep a read of the old one. An update ends the previous version's
        /// extension at once, as before, and its reload doesn't wait for a write: the sooner an
        /// extension of the previous version is gone, the less WidgetKit hears from it. The
        /// launch's first write, after the end, then reloads every placed kind through the planner
        /// (``WidgetReloadPlanner/Reason/repair``), so the extension the update starts finds the
        /// feed: after an update from 0.7.0 there was none.
        public var steps: [LaunchStep] {
            switch self {
            case .update: [.endExtension, .reload]
            case .language: [.writeFeed, .endExtension, .reload]
            }
        }
    }

    /// One step of what a launch does (``LaunchReason/steps``).
    public enum LaunchStep: String, Sendable, CaseIterable {
        /// Writes the widget feed with the app's languages, and waits for the write.
        case writeFeed
        /// Ends the widget extension a previous launch left running.
        case endExtension
        /// Reloads every kind a second later: after an update only when an extension was ended
        /// (``LaunchReason/reloadsAnyway``).
        case reload
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
/// first reload, and again while the answer lists no widget of the kind that is due (an empty or
/// failed answer included) once it is ``maximumAge`` old. So a widget placed since is reloaded
/// within that time while the app runs, and the counts the app logs follow it. Each answer
/// replaces the one before (``record(answer:at:)``), but a kind the answer lists is never asked
/// about again: once its last widget is removed, it still counts as placed until an answer asked
/// for a kind the answer leaves out no longer lists it, or until the app quits.
public struct WidgetPlacements: Sendable {
    static let maximumAge: TimeInterval = 15 * 60

    /// The kind strings of the last answer; empty before the first, after a failed one and after
    /// an empty one, which all count as every kind placed.
    private var listed: Set<String> = []
    private var answeredAt: Date?

    public init() {}

    /// Records WidgetKit's answer: the kind string of every placed widget, one per widget.
    public mutating func record(answer kinds: [String], at date: Date) {
        listed = Set(kinds)
        answeredAt = date
    }

    /// Records a failed answer, which counts as every kind placed.
    public mutating func recordFailure(at date: Date) {
        listed = []
        answeredAt = date
    }

    public func isPlaced(_ kind: WidgetKindID) -> Bool {
        listed.isEmpty || listed.contains(kind.rawValue)
    }

    /// Whether to ask WidgetKit before reloading `kind` at `date`.
    public func needsAnswer(toReload kind: WidgetKindID, at date: Date) -> Bool {
        guard let answeredAt else { return true }
        guard !listed.contains(kind.rawValue) else { return false }
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

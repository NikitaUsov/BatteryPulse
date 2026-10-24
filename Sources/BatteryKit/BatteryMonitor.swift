import BatteryCore
import Foundation
import Observation

#if canImport(os)
import os
#endif

/// Observable battery state for SwiftUI.
///
/// Event-driven by default: it re-reads only when the OS posts a power change, which costs
/// nothing while idle, and a burst of such notifications is one read (``requestRefresh()``).
/// Views that show fast-moving values (current, power) request polling with
/// ``setLiveRefreshInterval(_:for:)`` and withdraw it with `nil`; the shortest active request
/// wins. Polls fetch only what changes from poll to poll, in two separate decisions
/// (``BatteryReadScope``):
/// - The registry, which has new data when the OS posts a change, is fetched by every read but a
///   poll; a poll reuses the last read's while ``registryPolicy`` allows, at most 5 minutes.
/// - The SMC's slow values are read at most once a minute (``smcPolicy``) and on a
///   ``RefreshTrigger/manual`` read.
///
/// Both are fetched on every read while a view that shows them asks for it with
/// ``setShowsSlowValues(_:for:)``.
///
/// The reads themselves leave the main actor where the provider allows it
/// (``BatteryProvider/nonisolatedReader``): every trigger but the launch, Demo Mode and a manual
/// read (``readsOnMainActor(_:)``) reads in a `@concurrent` function, and the result is assigned
/// in one step when it lands. One such read runs at a time; the requests that arrive meanwhile make
/// one follow-on read.
@MainActor
@Observable
public final class BatteryMonitor {
    /// Latest parsed state. Only reassigned when something other than the timestamp changes,
    /// so views reading it don't re-render on identical readings.
    public private(set) var snapshot: BatterySnapshot?
    /// Latest reading including raw dictionaries. Like ``snapshot``, only reassigned when more
    /// than the timestamp changed.
    public private(set) var reading: BatteryReading?
    /// `false` once a read found no battery; `nil` before the first read.
    public private(set) var hasBattery: Bool?
    public private(set) var isRunning = false
    public private(set) var liveRefreshInterval: Duration?
    /// `true` while readings come from an override provider (Demo Mode) instead of the device.
    public private(set) var isOverridden = false
    /// When the battery was last read, whether or not the reading changed anything. Unlike
    /// ``snapshot``'s timestamp, which moves only with the state, this tells a caller that would
    /// read again whether a recent read is good enough. Not observed: it changes on every read.
    @ObservationIgnored public private(set) var lastReadAt: ContinuousClock.Instant?

    @ObservationIgnored private let provider: any BatteryProvider
    @ObservationIgnored private let clock: any MonitorClock
    @ObservationIgnored private var overrideProvider: (any BatteryProvider)?
    @ObservationIgnored private var observation: BatteryObservation?
    // Each task has a name ("BatteryMonitor.…") for Instruments' Swift Tasks view and the debugger.
    @ObservationIgnored private var liveRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var liveRefreshRequests: [String: Duration] = [:]
    @ObservationIgnored private var followUpTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    /// Runs the reads off the main actor, one at a time, while any is requested.
    @ObservationIgnored private var readLoop: Task<Void, Never>?
    /// What the next read off the main actor is for: the first request since the last one began.
    @ObservationIgnored private(set) var requestedTrigger: RefreshTrigger?
    /// Whether every request since the last read off the main actor began was a poll. One that
    /// wasn't, such as a notification's, makes the next read fetch the registry.
    @ObservationIgnored private var requestedPollsOnly = true
    /// Advanced by ``setOverride(_:)``, ``stop()`` and every read on the main actor. A read off the
    /// main actor is dropped when it lands in a later generation than it started in: it belongs to
    /// the device after Demo Mode started, to a stopped monitor, or is older than a read that landed
    /// first.
    @ObservationIgnored private var generation = 0
    /// When a read last fetched the slow values, on ``clock``.
    @ObservationIgnored private var slowValuesReadAt: ContinuousClock.Instant?
    /// When a read last fetched the registry, on ``clock``.
    @ObservationIgnored private var registryReadAt: ContinuousClock.Instant?
    @ObservationIgnored private var slowValueClients: Set<String> = []

    /// How often reads fetch the values that change slowly, such as the SMC's cell voltages and
    /// temperatures: at most once a minute, where a provider's own ``BatteryProvider/read()``
    /// fetches them every time.
    static let smcPolicy = SMCReadPolicy.everyMinute

    /// When polls may reuse the registry: ``RegistryReadPolicy/app`` in the app, whose reuse
    /// ``RegistryReadPolicy/cachesOnPolls`` switches off.
    let registryPolicy: RegistryReadPolicy

    /// How long a burst of change notifications may last: one read follows the first of them
    /// after this window, give or take ``coalescingTolerance``, which lets the OS fold the wake-up
    /// into another. Besides powerd's, Low Power Mode and thermal changes post their own
    /// notifications. Together the window and its tolerance delay a plug or unplug by at most
    /// 250 ms.
    static let coalescingWindow: Duration = .milliseconds(150)
    static let coalescingTolerance: Duration = .milliseconds(100)

    /// When extra reads follow the adapter being plugged in or out, counted from that moment.
    /// The OS posts one notification, but its own state and the registry take up to a minute to
    /// catch up, while the SMC shows the new current within seconds.
    @ObservationIgnored var powerChangeFollowUps: [Duration] = [
        .seconds(3), .seconds(8), .seconds(15), .seconds(30), .seconds(60),
    ]

    public convenience init(provider: any BatteryProvider) {
        self.init(provider: provider, clock: ContinuousClock())
    }

    /// - Parameters:
    ///   - provider: Reads the device's battery.
    ///   - clock: Times the polls, the follow-ups and the coalescing window, and stamps
    ///     ``lastReadAt``. Tests pass one they advance by hand.
    ///   - registryPolicy: When polls may reuse the registry. Tests pass both settings of the
    ///     switch.
    init(provider: any BatteryProvider, clock: any MonitorClock, registryPolicy: RegistryReadPolicy = .app) {
        self.provider = provider
        self.clock = clock
        self.registryPolicy = registryPolicy
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        observation = activeProvider.observeChanges { [weak self] in self?.providerChanged() }
        refresh(trigger: .launch)
        scheduleLiveRefresh()
    }

    /// Shows readings from `provider` instead of the device until called with `nil`. Polling
    /// requests carry over; the device's change notifications pause meanwhile.
    public func setOverride(_ provider: (any BatteryProvider)?) {
        overrideProvider = provider
        isOverridden = provider != nil
        // The device's registry and slow values are as old as the demo: read them with the
        // device's first.
        registryReadAt = nil
        slowValuesReadAt = nil
        // A read in flight belongs to the provider shown until now.
        generation += 1
        requestedTrigger = nil
        guard isRunning else { return }
        observation?.cancel()
        observation = activeProvider.observeChanges { [weak self] in self?.providerChanged() }
        refresh(trigger: .demo)
    }

    private var activeProvider: any BatteryProvider {
        overrideProvider ?? provider
    }

    /// A change notification of the device, read once its burst is over, or a step of the demo's,
    /// shown at once.
    private func providerChanged() {
        if overrideProvider == nil {
            requestRefresh()
        } else {
            refresh(trigger: .demo)
        }
    }

    public func stop() {
        isRunning = false
        // A read in flight can't be stopped, but its result is dropped.
        generation += 1
        requestedTrigger = nil
        observation?.cancel()
        observation = nil
        liveRefreshTask?.cancel()
        liveRefreshTask = nil
        followUpTask?.cancel()
        followUpTask = nil
        pendingRefresh?.cancel()
        pendingRefresh = nil
    }

    /// Requests polling at `interval` on behalf of `client` (e.g. "popover"); `nil` withdraws the
    /// request. Polls at the shortest active interval, or not at all without requests.
    public func setLiveRefreshInterval(_ interval: Duration?, for client: String = "default") {
        let isNewRequest = interval != nil && liveRefreshRequests[client] == nil
        liveRefreshRequests[client] = interval
        // A view that just appeared shouldn't wait a full interval for fresh values, but a read
        // under a second old is fresh enough: at launch, the menu bar's request would otherwise
        // read again right after `start()`.
        if isNewRequest, isRunning, !hasRead(within: .seconds(1)) { refresh(trigger: .poll) }

        let effective = liveRefreshRequests.values.min()
        guard effective != liveRefreshInterval else { return }
        liveRefreshInterval = effective
        #if canImport(os)
        // The clients are names from the code, such as "menuBar" and "popover".
        let clients = liveRefreshRequests.keys.sorted().joined(separator: ", ")
        if let effective {
            Diagnostics.monitor.debug(
                "Live refresh every \(effective.description, privacy: .public) for \(clients, privacy: .public)")
        } else {
            Diagnostics.monitor.debug("Live refresh off")
        }
        #endif
        scheduleLiveRefresh()
    }

    /// Asks for the values that change slowly, the registry's and the SMC's slow keys such as its
    /// cell voltages and temperatures, to be read on every read while `client` (e.g. "main") shows
    /// them; `false` withdraws the request. Without requests polls reuse the registry for up to
    /// 5 minutes and read the SMC's slow keys at most once a minute.
    public func setShowsSlowValues(_ shows: Bool, for client: String = "default") {
        guard shows != slowValueClients.contains(client) else { return }
        if shows {
            slowValueClients.insert(client)
        } else {
            slowValueClients.remove(client)
        }
        #if canImport(os)
        // The clients are names from the code, such as "main".
        let clients = slowValueClients.sorted().joined(separator: ", ")
        if clients.isEmpty {
            Diagnostics.monitor.debug("Slow values at most once a minute")
        } else {
            Diagnostics.monitor.debug("Slow values on every read for \(clients, privacy: .public)")
        }
        #endif
    }

    /// Whether the battery was read less than `age` ago, on the monitor's clock: a caller that
    /// would read again can use the current values instead.
    public func hasRead(within age: Duration) -> Bool {
        guard let lastReadAt else { return false }
        return clock.now - lastReadAt < age
    }

    /// Reads the battery once the current burst of change notifications is over: the first of them
    /// schedules a read ``coalescingWindow`` later, and the rest join it. For a value now, use
    /// ``refresh(trigger:)``.
    func requestRefresh() {
        guard isRunning, pendingRefresh == nil else { return }
        let clock = clock
        pendingRefresh = Task(name: "BatteryMonitor.pendingRefresh") { [weak self] in
            try? await clock.sleep(for: Self.coalescingWindow, tolerance: Self.coalescingTolerance)
            guard !Task.isCancelled, let self, self.isRunning else { return }
            self.pendingRefresh = nil
            self.refresh(trigger: .notify)
        }
    }

    /// Reads the battery now; a read that a notification scheduled is no longer needed. `trigger`
    /// labels the `refresh` interval and decides where the read runs: the launch, Demo Mode and a
    /// manual read (``readsOnMainActor(_:)``) are done when this returns. The other triggers read
    /// off the main actor when the provider can, and ``snapshot`` changes when the read lands; to
    /// wait for it, use ``refreshAndWait(trigger:)``.
    public func refresh(trigger: RefreshTrigger = .manual) {
        pendingRefresh?.cancel()
        pendingRefresh = nil
        if Self.readsOnMainActor(trigger) || activeProvider.nonisolatedReader == nil {
            readOnMainActor(trigger)
        } else {
            requestReadOffMainActor(trigger)
        }
    }

    /// ``refresh(trigger:)``, returning once ``snapshot`` holds what the read found, or what a
    /// newer read did.
    public func refreshAndWait(trigger: RefreshTrigger) async {
        refresh(trigger: trigger)
        await readLoop?.value
    }

    /// The reads that stay on the main actor whatever the provider: the launch read, which is the
    /// one read before `menuBarReady`; Demo Mode's, which `DemoController` animates in one
    /// transaction with its own changes; and a manual read, whose caller reads ``snapshot``
    /// straight after (Copy Report).
    static func readsOnMainActor(_ trigger: RefreshTrigger) -> Bool {
        switch trigger {
        case .launch, .demo, .manual: true
        case .notify, .poll, .followUp, .history: false
        }
    }

    /// Whether a read off the main actor is in flight or requested.
    var isReadingOffMainActor: Bool {
        readLoop != nil
    }

    private func readOnMainActor(_ trigger: RefreshTrigger) {
        let interval = Diagnostics.begin("refresh", trigger: trigger.name)
        defer { interval.end() }
        // Newer than a read in flight, which is dropped when it lands; it serves the requests that
        // wait for a follow-on read too.
        generation += 1
        requestedTrigger = nil
        let scope = readScope(for: trigger, isPoll: trigger == .poll)
        apply(activeProvider.read(scope: scope), scope: scope, trigger: trigger)
    }

    /// Starts a read off the main actor or, while one is in flight, asks for one after it: any
    /// number of requests meanwhile make one follow-on read, labelled with the first. It fetches
    /// what the requests need together: the registry, unless all of them were polls.
    private func requestReadOffMainActor(_ trigger: RefreshTrigger) {
        if requestedTrigger == nil {
            requestedTrigger = trigger
            requestedPollsOnly = trigger == .poll
        } else if trigger != .poll {
            requestedPollsOnly = false
        }
        guard readLoop == nil else { return }
        readLoop = Task(name: "BatteryMonitor.read") { [weak self] in
            await self?.readOffMainActor()
        }
    }

    /// Runs the requested reads one after another until none is left, each assigned in one step
    /// unless its ``generation`` has passed.
    private func readOffMainActor() async {
        while let trigger = requestedTrigger.take(), let reader = activeProvider.nonisolatedReader {
            let interval = Diagnostics.begin("refresh", trigger: trigger.name)
            let generation = generation
            let scope = readScope(for: trigger, isPoll: requestedPollsOnly)
            let new = await Self.read(reader, scope: scope)
            if generation == self.generation {
                apply(new, scope: scope, trigger: trigger)
            } else {
                #if canImport(os)
                Diagnostics.monitor.debug("A read that Demo Mode, stop() or a newer read superseded is dropped")
                #endif
            }
            interval.end()
        }
        readLoop = nil
    }

    /// Reads through `reader` on the global concurrent executor, so IOKit and the SMC never hold
    /// the main actor; only the result comes back.
    @concurrent
    private static func read(_ reader: any NonisolatedBatteryReader, scope: BatteryReadScope) async
        -> BatteryReading?
    {
        await reader.readNonisolated(scope: scope)
    }

    /// The two decisions of a read for `trigger`: the registry unless the read serves only polls
    /// (`isPoll`) and ``registryPolicy`` lets them reuse it, and every SMC key when the slow values
    /// are due (``smcPolicy``) or the caller needs every value now.
    private func readScope(for trigger: RefreshTrigger, isPoll: Bool) -> BatteryReadScope {
        let isShown = !slowValueClients.isEmpty
        let rereadsRegistry = registryPolicy.rereadsRegistry(
            isPoll: isPoll, age: registryReadAt.map { clock.now - $0 }, isShown: isShown)
        // A caller that needs a value now, such as Copy Report, gets the slow values fresh too.
        let readsAllSMCKeys =
            trigger == .manual
            || Self.smcPolicy.readsOtherKeys(age: slowValuesReadAt.map { clock.now - $0 }, isShown: isShown)
        return BatteryReadScope(rereadsRegistry: rereadsRegistry, readsAllSMCKeys: readsAllSMCKeys)
    }

    /// Takes what a read found. ``snapshot`` and ``reading`` are reassigned only when they change.
    private func apply(_ new: BatteryReading?, scope: BatteryReadScope, trigger: RefreshTrigger) {
        lastReadAt = clock.now
        if scope.rereadsRegistry { registryReadAt = lastReadAt }
        if scope.readsAllSMCKeys { slowValuesReadAt = lastReadAt }
        let wasConnected = snapshot?.isExternalPowerConnected
        if hasBattery != (new != nil) {
            logBatteryChange(found: new != nil, trigger: trigger)
            hasBattery = new != nil
        }
        if !Self.isSameReading(new, reading) { reading = new }
        if !Self.isSameState(new?.snapshot, snapshot) { snapshot = new?.snapshot }
        if let wasConnected, let isConnected = new?.snapshot.isExternalPowerConnected, isConnected != wasConnected {
            #if canImport(os)
            let reads = powerChangeFollowUps.count
            Diagnostics.monitor.debug("External power connected: \(isConnected); reading again \(reads) times")
            #endif
            scheduleFollowUps()
        }
    }

    /// A read found a battery where the previous one found none, or the other way around.
    private func logBatteryChange(found: Bool, trigger: RefreshTrigger) {
        #if canImport(os)
        if found {
            Diagnostics.monitor.info("Battery found")
        } else if hasBattery == true, overrideProvider == nil, trigger != .demo {
            // A battery doesn't go away: both the registry and the power source lookup failed. The
            // read that ends Demo Mode is no such case: on a Mac without one, the demo's was the last.
            Diagnostics.monitor.error("The battery read found no battery")
        } else {
            Diagnostics.monitor.info("No battery")
        }
        #endif
    }

    private func scheduleFollowUps() {
        followUpTask?.cancel()
        let delays = powerChangeFollowUps
        let clock = clock
        followUpTask = Task(name: "BatteryMonitor.followUps") { [weak self] in
            var previous = Duration.zero
            for delay in delays {
                // A tenth of each gap lets the OS coalesce the wake-up with others. Gaps rather
                // than deadlines: after the Mac sleeps through some, they don't all fire at once.
                let gap = delay - previous
                try? await clock.sleep(for: gap, tolerance: gap / 10)
                previous = delay
                guard !Task.isCancelled, let self, self.isRunning else { return }
                self.refresh(trigger: .followUp)
            }
        }
    }

    static func isSameReading(_ lhs: BatteryReading?, _ rhs: BatteryReading?) -> Bool {
        guard var lhs, let rhs else { return lhs == nil && rhs == nil }
        lhs.snapshot.timestamp = rhs.snapshot.timestamp
        return lhs == rhs
    }

    static func isSameState(_ lhs: BatterySnapshot?, _ rhs: BatterySnapshot?) -> Bool {
        guard var lhs, let rhs else { return lhs == nil && rhs == nil }
        lhs.timestamp = rhs.timestamp
        return lhs == rhs
    }

    private func scheduleLiveRefresh() {
        liveRefreshTask?.cancel()
        liveRefreshTask = nil
        guard isRunning, let interval = liveRefreshInterval else { return }
        let clock = clock
        liveRefreshTask = Task(name: "BatteryMonitor.liveRefresh") { [weak self] in
            while !Task.isCancelled {
                // Tolerance lets the OS coalesce wake-ups, which matters on battery.
                try? await clock.sleep(for: interval, tolerance: interval / 4)
                guard !Task.isCancelled, let self else { return }
                self.refresh(trigger: .poll)
            }
        }
    }
}

/// A clock in the continuous clock's time base, which ``BatteryMonitor`` sleeps on and stamps its
/// reads with: the system's, or a test's that moves only when told to.
protocol MonitorClock: Clock, Sendable where Instant == ContinuousClock.Instant {}

extension ContinuousClock: MonitorClock {}

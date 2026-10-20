import BatteryCore
import Foundation
import Observation

/// Observable battery state for SwiftUI.
///
/// Event-driven by default: it re-reads only when the OS posts a power change, which costs
/// nothing while idle, and a burst of such notifications is one read (``requestRefresh()``).
/// Views that show fast-moving values (current, power) request polling with
/// ``setLiveRefreshInterval(_:for:)`` and withdraw it with `nil`; the shortest active request
/// wins.
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
    @ObservationIgnored private var liveRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var liveRefreshRequests: [String: Duration] = [:]
    @ObservationIgnored private var followUpTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?

    /// How long a burst of change notifications may last: one read follows the first of them
    /// after this window, give or take ``coalescingTolerance``, which lets the OS fold the wake-up
    /// into another. powerd posts two notifications for one battery update, and Low Power Mode and
    /// thermal changes post their own. Together they delay a plug or unplug by at most 250 ms.
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
    init(provider: any BatteryProvider, clock: any MonitorClock) {
        self.provider = provider
        self.clock = clock
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
        // A view that just appeared shouldn't wait a full interval for fresh values.
        if isNewRequest, isRunning { refresh(trigger: .poll) }

        let effective = liveRefreshRequests.values.min()
        guard effective != liveRefreshInterval else { return }
        liveRefreshInterval = effective
        scheduleLiveRefresh()
    }

    /// Reads the battery once the current burst of change notifications is over: the first of them
    /// schedules a read ``coalescingWindow`` later, and the rest join it. For a value now, use
    /// ``refresh(trigger:)``.
    func requestRefresh() {
        guard isRunning, pendingRefresh == nil else { return }
        let clock = clock
        pendingRefresh = Task { [weak self] in
            try? await clock.sleep(for: Self.coalescingWindow, tolerance: Self.coalescingTolerance)
            guard !Task.isCancelled, let self, self.isRunning else { return }
            self.pendingRefresh = nil
            self.refresh(trigger: .notify)
        }
    }

    /// Reads the battery now; a read that a notification scheduled is no longer needed. `trigger`
    /// only labels the `refresh` interval.
    public func refresh(trigger: RefreshTrigger = .manual) {
        let interval = Diagnostics.begin("refresh", trigger: trigger.name)
        defer { interval.end() }
        pendingRefresh?.cancel()
        pendingRefresh = nil
        let new = activeProvider.read()
        lastReadAt = clock.now
        let wasConnected = snapshot?.isExternalPowerConnected
        if hasBattery != (new != nil) { hasBattery = new != nil }
        if !Self.isSameReading(new, reading) { reading = new }
        if !Self.isSameState(new?.snapshot, snapshot) { snapshot = new?.snapshot }
        if let wasConnected, let isConnected = new?.snapshot.isExternalPowerConnected, isConnected != wasConnected {
            scheduleFollowUps()
        }
    }

    private func scheduleFollowUps() {
        followUpTask?.cancel()
        let delays = powerChangeFollowUps
        let clock = clock
        followUpTask = Task { [weak self] in
            var elapsed = Duration.zero
            for delay in delays {
                try? await clock.sleep(for: delay - elapsed)
                elapsed = delay
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
        liveRefreshTask = Task { [weak self] in
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

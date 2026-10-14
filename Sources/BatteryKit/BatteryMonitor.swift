import Foundation
import Observation
import BatteryCore

/// Observable battery state for SwiftUI.
///
/// Event-driven by default: it re-reads only when the OS posts a power change, which costs
/// nothing while idle. Call ``setLiveRefreshInterval(_:)`` while a view shows fast-moving
/// values (current, power) and reset it to `nil` when that view disappears.
@MainActor
@Observable
public final class BatteryMonitor {
    /// Latest parsed state. Only reassigned when something other than the timestamp changes,
    /// so views reading it don't re-render on identical readings.
    public private(set) var snapshot: BatterySnapshot?
    /// Latest reading including raw dictionaries, updated whenever it differs.
    public private(set) var reading: BatteryReading?
    /// `false` once a read found no battery; `nil` before the first read.
    public private(set) var hasBattery: Bool?
    public private(set) var isRunning = false
    public private(set) var liveRefreshInterval: Duration?

    @ObservationIgnored private let provider: any BatteryProvider
    @ObservationIgnored private var observation: BatteryObservation?
    @ObservationIgnored private var liveRefreshTask: Task<Void, Never>?

    public init(provider: any BatteryProvider) {
        self.provider = provider
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        observation = provider.observeChanges { [weak self] in self?.refresh() }
        refresh()
        scheduleLiveRefresh()
    }

    public func stop() {
        isRunning = false
        observation?.cancel()
        observation = nil
        liveRefreshTask?.cancel()
        liveRefreshTask = nil
    }

    /// Polls at `interval` while running; `nil` returns to purely event-driven updates.
    public func setLiveRefreshInterval(_ interval: Duration?) {
        guard interval != liveRefreshInterval else { return }
        liveRefreshInterval = interval
        scheduleLiveRefresh()
    }

    public func refresh() {
        let new = provider.read()
        if hasBattery != (new != nil) { hasBattery = new != nil }
        if new != reading { reading = new }
        if !Self.isSameState(new?.snapshot, snapshot) { snapshot = new?.snapshot }
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
        liveRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                // Tolerance lets the OS coalesce wake-ups, which matters on battery.
                try? await Task.sleep(for: interval, tolerance: interval / 4)
                guard !Task.isCancelled, let self else { return }
                self.refresh()
            }
        }
    }
}

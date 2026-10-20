import BatteryCore
import Foundation
import Observation

/// Observable accessory batteries for SwiftUI and the notifier.
///
/// Separate from ``BatteryMonitor``: the notifications and their cadence differ, the Mac's live
/// polling must not re-read accessories, views of the Mac's battery must not re-render on an
/// accessory change, and a Mac without a battery still has accessories. Event-driven only: a
/// burst of change notifications is one read ``coalescingDelay`` after the first of them, and
/// views add one read each time they become visible (`refresh()`). There is no timer.
@MainActor
@Observable
public final class AccessoryMonitor {
    /// Reassigned only when the list changed, so views and the notifier don't react to equal
    /// reads.
    public private(set) var accessories: [AccessoryBattery] = []
    /// `nil` before the first read; `false` when this system doesn't publish accessory
    /// batteries.
    public private(set) var isAvailable: Bool?
    /// `true` while readings come from an override provider (Demo Mode).
    public private(set) var isOverridden = false

    @ObservationIgnored private let provider: (any AccessoryProvider)?
    @ObservationIgnored private var overrideProvider: (any AccessoryProvider)?
    @ObservationIgnored private var observation: BatteryObservation?
    @ObservationIgnored private var pendingRead: Task<Void, Never>?
    @ObservationIgnored public private(set) var isRunning = false
    /// Notifications come in bursts (an accessory attaching posts two); one read follows the
    /// first of them after this delay.
    @ObservationIgnored var coalescingDelay: Duration = .milliseconds(250)

    /// - Parameter provider: `nil` where accessory batteries aren't published; the monitor then
    ///   reports them as unavailable.
    public init(provider: (any AccessoryProvider)?) {
        self.provider = provider
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        observeActiveProvider()
        refresh()
    }

    public func stop() {
        isRunning = false
        observation?.cancel()
        observation = nil
        pendingRead?.cancel()
        pendingRead = nil
    }

    /// Reads now; a read scheduled by a notification is no longer needed.
    public func refresh() {
        pendingRead?.cancel()
        pendingRead = nil
        let reading = Diagnostics.measure("accessory.read") { activeProvider?.read() }
        let isAvailable = reading != nil
        if self.isAvailable != isAvailable { self.isAvailable = isAvailable }
        let accessories = reading?.accessories ?? []
        if self.accessories != accessories { self.accessories = accessories }
    }

    /// Shows readings from `provider` instead of the system's until called with `nil`, like
    /// ``BatteryMonitor/setOverride(_:)``; the system's notifications pause meanwhile.
    public func setOverride(_ provider: (any AccessoryProvider)?) {
        overrideProvider = provider
        if isOverridden != (provider != nil) { isOverridden = provider != nil }
        guard isRunning else { return }
        observeActiveProvider()
        refresh()
    }

    private var activeProvider: (any AccessoryProvider)? {
        overrideProvider ?? provider
    }

    private func observeActiveProvider() {
        observation?.cancel()
        observation = activeProvider?.observeChanges { [weak self] in self?.scheduleRead() }
    }

    /// One read after ``coalescingDelay``, unless one is already pending.
    func scheduleRead() {
        guard pendingRead == nil else { return }
        let delay = coalescingDelay
        pendingRead = Task { [weak self] in
            // Tolerance lets the OS coalesce the wake-up with others.
            try? await Task.sleep(for: delay, tolerance: delay / 2)
            guard !Task.isCancelled, let self, self.isRunning else { return }
            self.pendingRead = nil
            self.refresh()
        }
    }
}

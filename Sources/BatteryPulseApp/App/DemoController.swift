#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import Foundation
import Observation
import SwiftUI

/// Demo Mode: simulated battery states shown everywhere in the app (main window, menu bar and
/// popover), picked by hand or played as a tour that also switches pages. Fixed demo accessories
/// replace the connected ones meanwhile, so screenshots never show a person's accessory names.
@MainActor
@Observable
final class DemoController {
    enum Step: Hashable {
        case scene(DemoScenario)
        case animation(DemoAnimation)
    }

    /// A request to show a page. The serial makes every step navigate, even to the same page.
    struct PageRequest: Equatable {
        var page: SidebarItem
        var serial: Int
    }

    /// The tour: each step and the page that shows it best.
    static let tour: [(step: Step, page: SidebarItem)] = [
        (.animation(.chargeFromEmpty), .overview),
        (.scene(.fullyCharged), .overview),
        (.scene(.charging), .power),
        (.scene(.justPluggedIn), .overview),
        (.scene(.onBattery), .overview),
        (.scene(.heavyLoad), .power),
        (.animation(.drainToEmpty), .overview),
        (.scene(.lowBattery), .overview),
        (.scene(.criticalBattery), .overview),
        (.scene(.lowPowerMode), .power),
        (.scene(.optimizedHold), .overview),
        (.scene(.slowCharger), .power),
        (.scene(.wornBattery), .health),
        (.scene(.noBattery), .overview),
        (.scene(.charging), .developer),
    ]

    static let sceneLengths: [Duration] = [.seconds(5), .seconds(10), .seconds(20)]

    /// What the demo shows; `nil` when Demo Mode is off.
    private(set) var step: Step?
    /// The tour moves on by itself.
    private(set) var isPlaying = false
    private(set) var pageRequest: PageRequest?
    /// How long the tour stays on a scene; animations take their own time.
    var sceneLength: Duration = .seconds(5)

    var isActive: Bool { step != nil }

    @ObservationIgnored private let monitor: BatteryMonitor
    @ObservationIgnored private let provider = DemoBatteryProvider()
    @ObservationIgnored private let accessories: AccessoryMonitor
    @ObservationIgnored private let accessoryProvider = DemoAccessoryProvider()
    /// Runs only while something moves: stopped while paused and once an animation shown by hand
    /// has finished.
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var elapsed: Duration = .zero
    @ObservationIgnored private var tourIndex = 0
    @ObservationIgnored private var variation = 0
    @ObservationIgnored private var defaultsObserver: (any NSObjectProtocol)?

    /// The clock while an animation plays: one frame.
    private static let frame: Duration = .milliseconds(200)
    /// The clock on a scene, which only varies its live values once a second.
    private static let sceneTick: Duration = .seconds(1)

    /// The motion of the demo's own transactions, which wrap every change of step, playback or
    /// page in `change` and each animation frame in `linear(_:)`. A controller can't read
    /// `\.motion`, so it asks the system for Reduce Motion each time; under it both are `nil`, so
    /// the demo bar, the page and its layout change at once, and only what fades on its own
    /// (the bar appearing, symbols, numbers) fades. A window that can't be seen still drops
    /// every animation at its root (`motionPolicy()`), and views keyed on their own state replace
    /// these with their own presets.
    private var motion: MotionPolicy {
        MotionPolicy(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    init(monitor: BatteryMonitor, accessories: AccessoryMonitor) {
        self.monitor = monitor
        self.accessories = accessories
        // Demo Mode lives in the Developer section: hiding the section ends the demo, even when
        // no window is open to notice.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive,
                    !UserDefaults.standard.bool(forKey: AppSettings.showDeveloperKey)
                else { return }
                self.stop()
            }
        }
    }

    // MARK: - Controls

    func startTour() {
        go(toTourStep: isActive ? tourIndex : 0, isPlaying: true)
    }

    /// Shows one step by hand; the tour pauses.
    func show(_ step: Step) {
        // Every step is in the tour, so Previous and Next continue from its neighbours.
        tourIndex = Self.tour.firstIndex { $0.step == step } ?? -1
        begin(step, page: Self.page(for: step), isPlaying: false)
    }

    /// Pause freezes everything, animations included, and stops the clock; Play continues where
    /// it stopped.
    func togglePlayback() {
        if isPlaying {
            stopClock()
            withAnimation(motion.change) { isPlaying = false }
        } else if let step {
            withAnimation(motion.change) { isPlaying = true }
            switch step {
            case .scene:
                // Give the current scene a full turn before moving on.
                elapsed = .zero
                startClock()
            case .animation(let animation):
                if elapsed >= animation.duration { next() } else { startClock() }
            }
        } else {
            startTour()
        }
    }

    func next() {
        go(toTourStep: tourIndex + 1)
    }

    func previous() {
        go(toTourStep: tourIndex - 1)
    }

    /// Ends Demo Mode; real readings come back at once.
    func stop() {
        stopClock()
        tourIndex = 0
        // One transaction: the bar dissolves while the real readings come back.
        withAnimation(motion.change) {
            step = nil
            isPlaying = false
            monitor.setOverride(nil)
        }
        // Outside the transaction: accessory cards come and go without animation. One read
        // brings the connected accessories back.
        accessories.setOverride(nil)
        provider.battery = nil
    }

    // MARK: - Running

    static func page(for step: Step) -> SidebarItem {
        tour.first { $0.step == step }?.page ?? .overview
    }

    /// `isPlaying` `nil` keeps playback as it is.
    private func go(toTourStep index: Int, isPlaying: Bool? = nil) {
        let count = Self.tour.count
        tourIndex = (index % count + count) % count
        let entry = Self.tour[tourIndex]
        begin(entry.step, page: entry.page, isPlaying: isPlaying)
    }

    private func begin(_ step: Step, page: SidebarItem, isPlaying: Bool? = nil) {
        elapsed = .zero
        provider.gaugeUpdatedAt = Date()
        // One transaction for the step, the page and the data, so the bar, its title, the
        // checkmark and the page land together with the numbers.
        withAnimation(motion.change) {
            if let isPlaying { self.isPlaying = isPlaying }
            self.step = step
            pageRequest = PageRequest(page: page, serial: (pageRequest?.serial ?? 0) + 1)
            provider.battery = battery(for: step, progress: 0)
            if !monitor.isOverridden { monitor.setOverride(provider) }
        }
        if !accessories.isOverridden { accessories.setOverride(accessoryProvider) }
        startClock()
    }

    private func battery(for step: Step, progress: Double) -> DemoBattery? {
        switch step {
        case .scene(let scenario): scenario.battery
        case .animation(let animation): animation.battery(progress: progress)
        }
    }

    /// (Re)starts the clock at the pace of the current step: every frame for an animation, once
    /// a second for a scene.
    private func startClock() {
        clock?.cancel()
        guard let step else {
            clock = nil
            return
        }
        let tick: Duration
        switch step {
        case .animation: tick = Self.frame
        case .scene: tick = Self.sceneTick
        }
        clock = Task(name: "DemoController.clock") { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tick)
                guard !Task.isCancelled, let self else { return }
                self.advance(by: tick)
            }
        }
    }

    private func stopClock() {
        clock?.cancel()
        clock = nil
    }

    private func advance(by tick: Duration) {
        guard let step else { return }
        elapsed += tick
        switch step {
        case .animation(let animation):
            let progress = elapsed / animation.duration
            // Linear up to the next frame, so the charge moves steadily.
            withAnimation(motion.linear(Self.frame / .seconds(1))) {
                provider.battery = animation.battery(progress: progress)
            }
            if progress >= 1 {
                // By hand, the animation holds its final state, and nothing moves until the
                // next step.
                if isPlaying { next() } else { stopClock() }
            }
        case .scene(let scenario):
            // Keep live values moving, the way real power readings do. Like real readings they
            // change instantly: the variation touches only the watts, which never animate, and
            // views keyed on their own state still animate a discrete change.
            variation += 1
            provider.battery = scenario.battery?.varied(variation)
            if isPlaying, elapsed >= sceneLength { next() }
        }
    }
}

// MARK: - Presentation

extension DemoController.Step {
    var title: LocalizedStringKey {
        switch self {
        case .scene(let scenario): scenario.title
        case .animation(let animation): animation.title
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .scene(let scenario): scenario.subtitle
        case .animation(let animation): animation.subtitle
        }
    }

    var symbol: String {
        switch self {
        case .scene(let scenario): scenario.symbol
        case .animation(.chargeFromEmpty): "arrow.up.circle"
        case .animation(.drainToEmpty): "arrow.down.circle"
        }
    }

    /// What the step's symbol is tinted for; the tone map picks the colour.
    var toneKind: DemoStepKind {
        switch self {
        case .scene(.charging), .scene(.fullyCharged), .scene(.justPluggedIn), .animation(.chargeFromEmpty): .charging
        case .scene(.lowBattery), .scene(.wornBattery), .scene(.slowCharger), .scene(.lowPowerMode): .warning
        case .scene(.criticalBattery), .scene(.heavyLoad), .animation(.drainToEmpty): .critical
        case .scene(.onBattery), .scene(.optimizedHold), .scene(.noBattery): .neutral
        }
    }
}

extension DemoScenario {
    var title: LocalizedStringKey {
        switch self {
        case .charging: "Fast charging"
        case .onBattery: "On battery"
        case .lowBattery: "Low battery"
        case .criticalBattery: "Critical battery"
        case .fullyCharged: "Fully charged"
        case .optimizedHold: "Optimized charging"
        case .justPluggedIn: "Just plugged in"
        case .wornBattery: "Worn battery"
        case .heavyLoad: "Heavy load"
        case .slowCharger: "Slow charger"
        case .lowPowerMode: "Low Power Mode"
        case .noBattery: "No battery"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .charging: "A 60 W USB-C adapter charges the battery."
        case .onBattery: "Everyday work, unplugged."
        case .lowBattery: "Below 20 percent, the charge turns orange."
        case .criticalBattery: "Below 10 percent, the charge turns red."
        case .fullyCharged: "Plugged in and full; the adapter powers the Mac."
        case .optimizedHold: "macOS holds the charge at 80 percent to slow battery aging."
        case .justPluggedIn: "macOS is still estimating the time to full."
        case .wornBattery: "Past its rated cycles and below 80 percent capacity: service recommended."
        case .heavyLoad: "Rendering or gaming: high power draw and an elevated thermal state."
        case .slowCharger: "A 15 W phone charger barely keeps up."
        case .lowPowerMode: "Reduced performance to make the battery last."
        case .noBattery: "How BatteryPulse looks on a Mac without a battery."
        }
    }

    var symbol: String {
        switch self {
        case .charging: "bolt.fill"
        case .onBattery: "battery.75percent"
        case .lowBattery: "battery.25percent"
        case .criticalBattery: "battery.0percent"
        case .fullyCharged: "battery.100percent"
        case .optimizedHold: "pause.circle"
        case .justPluggedIn: "powerplug.portrait.fill"
        case .wornBattery: "exclamationmark.triangle"
        case .heavyLoad: "flame"
        case .slowCharger: "tortoise"
        case .lowPowerMode: "leaf"
        case .noBattery: "desktopcomputer"
        }
    }
}

extension DemoAnimation {
    var title: LocalizedStringKey {
        switch self {
        case .chargeFromEmpty: "Charge from empty"
        case .drainToEmpty: "Drain to empty"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .chargeFromEmpty: "From 2 percent to full in 20 seconds, with the charge power tapering near the top."
        case .drainToEmpty: "From full to 2 percent in 20 seconds, through the low and critical levels."
        }
    }
}
#endif

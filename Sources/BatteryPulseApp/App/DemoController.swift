#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import Observation
import SwiftUI

/// Demo Mode: simulated battery states shown everywhere in the app (main window, menu bar and
/// popover), picked by hand or played as a tour that also switches pages.
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
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var elapsed: Duration = .zero
    @ObservationIgnored private var nextVariation: Duration = .zero
    @ObservationIgnored private var tourIndex = 0
    @ObservationIgnored private var variation = 0
    /// Paused by the user: animations hold their frame until playback resumes.
    @ObservationIgnored private var isFrozen = false
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?

    /// Animation frame and clock resolution.
    private static let frame: Duration = .milliseconds(200)

    init(monitor: BatteryMonitor) {
        self.monitor = monitor
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
        isPlaying = true
        go(toTourStep: isActive ? tourIndex : 0)
    }

    /// Shows one step by hand; the tour pauses.
    func show(_ step: Step) {
        isPlaying = false
        // Every step is in the tour, so Previous and Next continue from its neighbours.
        tourIndex = Self.tour.firstIndex { $0.step == step } ?? -1
        begin(step, page: Self.page(for: step))
    }

    /// Pause freezes everything, animations included; Play continues where it stopped.
    func togglePlayback() {
        if isPlaying {
            isPlaying = false
            isFrozen = true
        } else if let step {
            isPlaying = true
            isFrozen = false
            switch step {
            case .scene:
                // Give the current scene a full turn before moving on.
                elapsed = .zero
                nextVariation = .seconds(1)
            case .animation(let animation):
                if elapsed >= animation.duration { next() }
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
        clock?.cancel()
        clock = nil
        step = nil
        isPlaying = false
        isFrozen = false
        tourIndex = 0
        withAnimation(.smooth) { monitor.setOverride(nil) }
        provider.battery = nil
    }

    // MARK: - Running

    static func page(for step: Step) -> SidebarItem {
        tour.first { $0.step == step }?.page ?? .overview
    }

    private func go(toTourStep index: Int) {
        let count = Self.tour.count
        tourIndex = (index % count + count) % count
        let entry = Self.tour[tourIndex]
        begin(entry.step, page: entry.page)
    }

    private func begin(_ step: Step, page: SidebarItem) {
        self.step = step
        pageRequest = PageRequest(page: page, serial: (pageRequest?.serial ?? 0) + 1)
        elapsed = .zero
        nextVariation = .seconds(1)
        isFrozen = false
        provider.gaugeUpdatedAt = Date()
        withAnimation(.smooth) {
            provider.battery = battery(for: step, progress: 0)
            if !monitor.isOverridden { monitor.setOverride(provider) }
        }
        startClock()
    }

    private func battery(for step: Step, progress: Double) -> DemoBattery? {
        switch step {
        case .scene(let scenario): scenario.battery
        case .animation(let animation): animation.battery(progress: progress)
        }
    }

    private func startClock() {
        guard clock == nil else { return }
        clock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.frame)
                guard !Task.isCancelled, let self else { return }
                self.advance()
            }
        }
    }

    private func advance() {
        guard let step, !isFrozen else { return }
        elapsed += Self.frame
        switch step {
        case .animation(let animation):
            let progress = elapsed / animation.duration
            withAnimation(.linear(duration: 0.2)) {
                provider.battery = animation.battery(progress: progress)
            }
            // By hand, the animation holds its final state.
            if progress >= 1, isPlaying { next() }
        case .scene(let scenario):
            // Keep live values moving, the way real power readings do.
            if elapsed >= nextVariation {
                nextVariation += .seconds(1)
                variation += 1
                withAnimation(.smooth) { provider.battery = scenario.battery?.varied(variation) }
            }
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

    var tint: Color {
        switch self {
        case .scene(.charging), .scene(.fullyCharged), .scene(.justPluggedIn), .animation(.chargeFromEmpty): .green
        case .scene(.lowBattery), .scene(.wornBattery), .scene(.slowCharger), .scene(.lowPowerMode): .orange
        case .scene(.criticalBattery), .scene(.heavyLoad), .animation(.drainToEmpty): .red
        case .scene(.onBattery), .scene(.optimizedHold), .scene(.noBattery): .accentColor
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

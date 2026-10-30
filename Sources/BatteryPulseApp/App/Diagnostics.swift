#if os(macOS)
import BatterySource
import Synchronization
import os

/// The app's loggers, one per area, and its signposts: Points of Interest intervals for
/// Instruments and the `perf` lines that `log stream` shows (``Signposts``). BatterySource has a
/// twin for the reads and BatteryKit's monitors. Error descriptions, paths, device names, serials
/// and UDIDs never log as public. Nonisolated, unlike the rest of the app: the work off the main
/// actor logs and measures too.
nonisolated enum Diagnostics {
    static let subsystem = "io.github.nikitausov.BatteryPulse"

    static let monitor = Logger(subsystem: subsystem, category: "monitor")
    static let smc = Logger(subsystem: subsystem, category: "smc")
    static let iokit = Logger(subsystem: subsystem, category: "iokit")
    static let history = Logger(subsystem: subsystem, category: "history")
    static let device = Logger(subsystem: subsystem, category: "device")
    static let accessory = Logger(subsystem: subsystem, category: "accessory")
    static let update = Logger(subsystem: subsystem, category: "update")
    static let widget = Logger(subsystem: subsystem, category: "widget")
    /// The `perf` lines of ``signposts``.
    static let perf = Logger(subsystem: subsystem, category: "perf")
    static let signposts = Signposts(subsystem: subsystem, log: perf)

    static func begin(_ name: StaticString, trigger: StaticString? = nil) -> Signposts.Interval {
        signposts.begin(name, trigger: trigger)
    }

    static func measure<T>(_ name: StaticString, trigger: StaticString? = nil, _ body: () throws -> T) rethrows -> T {
        try signposts.measure(name, trigger: trigger, body)
    }

    static func event(_ name: StaticString, trigger: StaticString? = nil) {
        signposts.event(name, trigger: trigger)
    }

    // MARK: Page switches

    /// `page.switch`: from a change of the main window's page until the new page appears.
    private static let pageSwitch = Mutex<Signposts.Interval?>(nil)

    /// The main window's page is changing. Another change before a page appears keeps the first
    /// start, which is when the user asked.
    static func pageWillSwitch() {
        pageSwitch.withLock { interval in
            if interval == nil { interval = begin("page.switch") }
        }
    }

    /// A page of the main window appeared; ends a page switch with the page's name.
    static func pageAppeared(_ page: SidebarItem) {
        let pending = pageSwitch.withLock { interval in
            defer { interval = nil }
            return interval
        }
        guard var interval = pending else { return }
        interval.trigger = page.signpostName
        interval.end()
    }

    // MARK: Menu bar

    /// Emits `menuBarReady` when first read: a `static let` is initialized once per process.
    private static let menuBarReady: Void = event("menuBarReady")

    /// `menuBarReady`, once per process: the status item's label appeared for the first time.
    /// Its later appearances don't count.
    static func menuBarAppeared() {
        menuBarReady
    }
}

extension SidebarItem {
    /// The page in a `page.switch` interval: a static name, so no device key reaches the log.
    /// Nonisolated, like ``Diagnostics/pageAppeared(_:)``.
    nonisolated var signpostName: StaticString {
        switch self {
        case .overview: "overview"
        case .power: "power"
        case .health: "health"
        case .history: "history"
        case .developer: "developer"
        case .demo: "demo"
        case .devicesIntro: "devices"
        case .device: "device"
        case .accessories: "accessories"
        }
    }
}
#endif

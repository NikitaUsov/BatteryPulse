import Foundation

/// How often a view's live values are read while the system asks apps to save energy.
///
/// A view that shows values without OS notifications (power, current) asks the monitor to poll
/// at its own interval: 2 s for a window, 10 s for the menu bar (``MenuBarContent``). Under Low
/// Power Mode, the system's request to reduce resource usage, or a serious or worse thermal
/// state, the poll slows down: a window's 2 s becomes 5 s and the menu bar's 10 s becomes 30 s.
///
/// The inputs come from the system (`ProcessInfo` and SwiftUI's environment), never from a
/// snapshot: a Demo Mode scene that simulates Low Power Mode or heat leaves the real poll alone.
/// A change only sets the next interval; nothing is read because of it.
public enum LiveRefreshPolicy {
    /// The interval to poll at for a view that asks for `base`.
    /// `reducesResources` is Low Power Mode or the system's request to reduce resource usage.
    public static func interval(base: Duration, reducesResources: Bool, thermal: ThermalState) -> Duration {
        guard reducesResources || slowsDown(for: thermal) else { return base }
        return reduced(base)
    }

    /// Whether the thermal state asks apps to do less: serious or critical. At serious, Apple
    /// asks apps to reduce CPU usage and I/O.
    public static func slowsDown(for thermal: ThermalState) -> Bool {
        switch thermal {
        case .nominal, .fair: false
        case .serious, .critical: true
        }
    }

    /// `base` while saving energy: a window's poll (2 s or faster) every 5 s, a slower one, such
    /// as the menu bar's 10 s, at a third of its rate.
    static func reduced(_ base: Duration) -> Duration {
        base <= .seconds(2) ? .seconds(5) : base * 3
    }
}

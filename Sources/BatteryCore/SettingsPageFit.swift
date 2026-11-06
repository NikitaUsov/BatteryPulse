import Foundation

/// How tall a settings page may grow before it scrolls: each pane of the Settings window, and the
/// welcome window's settings.
///
/// A page is as tall as its rows while it fits, so a short pane leaves no empty space and shows no
/// scroll bar. Above the cap it keeps the cap's height and scrolls, so its last rows stay
/// reachable on a short screen. The cap is the shortest screen's visible height (its area without
/// the menu bar and the Dock), less what the window shows around the page (``chrome``) and a
/// ``margin``, never under a ``floor``. The shortest screen, because a window moves between
/// screens without asking: it fits on every one.
public struct SettingsPageFit: Sendable, Equatable {
    /// What the window shows around the page, in points, top and bottom together.
    public var chrome: Double

    public init(chrome: Double) {
        self.chrome = chrome
    }

    /// The Settings window: its title bar and its tab bar, the tabs' symbols over their names. A
    /// window with a preference-style toolbar of four tabs measured 88 points of them on CI's
    /// macOS 27; 12 more to spare.
    public static let settings = SettingsPageFit(chrome: 100)

    /// The welcome window: its title bar (32 points on CI's macOS 27), its 24-point padding at
    /// the top and the bottom, the header (the 128-point icon), the large buttons (28 points) and
    /// the 18-point spacing above and below the page, 272 points; 8 more to spare.
    public static let welcome = SettingsPageFit(chrome: 280)

    /// Room left between a window at the cap and the edges of the visible area, top and bottom
    /// together, in points: the window doesn't touch the menu bar or the Dock.
    public static let margin: Double = 24

    /// The least height of a page's cap, in points, about four rows: on a screen too short even
    /// for that, the page keeps this height and scrolls within it.
    public static let floor: Double = 200

    /// The tallest the page may be on screens whose visible heights are `visibleHeights`, in
    /// points: the shortest one's, less ``chrome`` and ``margin``, and at least ``floor``.
    /// A height that isn't a positive number counts as no screen; with no screen there is no cap
    /// (infinity), and the page is as tall as its rows.
    public func cap(visibleHeights: [Double]) -> Double {
        guard let shortest = visibleHeights.filter({ $0.isFinite && $0 > 0 }).min() else { return .infinity }
        return max(shortest - chrome - Self.margin, Self.floor)
    }

    /// The page's height: its `ideal` height (as tall as its rows) up to `cap`, and the cap
    /// above it.
    public static func height(ideal: Double, cap: Double) -> Double {
        min(ideal, cap)
    }
}

import Foundation

/// What a drawn battery icon shows, decided from a reading. The app draws it with SwiftUI shapes
/// following ``BatteryIconLayout``.
public struct BatteryIconState: Sendable, Equatable, Hashable {
    /// The mark over (or next to) the battery.
    public enum Glyph: Sendable, Equatable, Hashable {
        case none
        /// Charging.
        case bolt
        /// On external power but not charging: full, held by Optimized Battery Charging or the
        /// charge limit, or the first seconds after plugging in.
        case plug
    }

    /// The colour of the fill.
    public enum Tint: Sendable, Equatable, Hashable {
        /// The menu bar's own text colour, like every other part of the icon.
        case monochrome
        /// Red: the charge is low (``BatteryPresentation/levelTier(for:)``).
        case low
        /// Yellow: Low Power Mode is on.
        case lowPower
    }

    /// The charge, 0...1.
    public var level: Double
    /// The charge in whole percent, for the number inside the battery; `nil` before a reading.
    public var percent: Int?
    public var glyph: Glyph
    public var tint: Tint

    public init(level: Double, percent: Int? = nil, glyph: Glyph = .none, tint: Tint = .monochrome) {
        self.level = min(1, max(0, level))
        self.percent = percent
        self.glyph = glyph
        self.tint = tint
    }

    /// The states macOS shows in its own battery item: a bolt while charging, a plug while on
    /// power without charging, a red fill when low and a yellow one in Low Power Mode, which
    /// wins over red as on iPhone.
    public init(snapshot s: BatterySnapshot?) {
        guard let s else {
            self.init(level: 0)
            return
        }
        let percent = s.chargePercent.map { Int(min(100, max(0, $0)).rounded()) }
        let isPluggedIn = s.isExternalPowerConnected ?? (s.chargeState == .charged || s.chargeState == .notCharging)
        let glyph: Glyph =
            if s.chargeState == .charging {
                .bolt
            } else if isPluggedIn {
                .plug
            } else {
                .none
            }
        let tint: Tint =
            if s.isLowPowerModeEnabled == true {
                .lowPower
            } else if BatteryPresentation.levelTier(for: s) != .normal {
                .low
            } else {
                .monochrome
            }
        self.init(level: (s.chargePercent ?? 0) / 100, percent: percent, glyph: glyph, tint: tint)
    }

    /// A monochrome icon becomes a template image that follows light and dark menu bars; a red
    /// or yellow fill keeps its colour.
    public var isMonochrome: Bool { tint == .monochrome }

    /// What Settings shows for each style.
    public static let sample = BatteryIconState(level: 0.7, percent: 70)
}

/// A point in icon coordinates: points, origin at the top left, y growing downward (as in SwiftUI).
public struct IconPoint: Sendable, Equatable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A rectangle in icon coordinates.
public struct IconRect: Sendable, Equatable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }

    public func insetBy(_ amount: Double) -> IconRect {
        IconRect(x: x + amount, y: y + amount, width: width - amount * 2, height: height - amount * 2)
    }

    /// A rectangle of `width` × `height` centred on this one's centre.
    public func centered(width: Double, height: Double) -> IconRect {
        IconRect(x: midX - width / 2, y: midY - height / 2, width: width, height: height)
    }
}

/// A rounded rectangle, one piece of a glyph.
public struct IconRoundedRect: Sendable, Equatable, Hashable {
    public var rect: IconRect
    public var cornerRadius: Double

    public init(rect: IconRect, cornerRadius: Double) {
        self.rect = rect
        self.cornerRadius = cornerRadius
    }
}

/// The bolt and the plug drawn on the battery, as plain geometry.
public enum BatteryIconGlyphs {
    /// Width over height of a glyph's box.
    public static func aspectRatio(_ glyph: BatteryIconState.Glyph) -> Double {
        switch glyph {
        case .none: 1
        case .bolt: 0.6
        case .plug: 1.5
        }
    }

    /// The lightning bolt as a closed polygon filling `rect` (best at a 0.6 aspect ratio). It is
    /// point-symmetric about the centre, so it sits centred on the battery.
    public static func bolt(in rect: IconRect) -> [IconPoint] {
        // On a 6 × 10 grid: the top tip, down to the left, in, down to the bottom tip, up to the
        // right and back in.
        let grid: [(Double, Double)] = [(3.84, 0), (0, 5.8), (2.64, 5.8), (2.16, 10), (6, 4.2), (3.36, 4.2)]
        return grid.map { IconPoint(x: rect.x + $0.0 / 6 * rect.width, y: rect.y + $0.1 / 10 * rect.height) }
    }

    /// A plug pointing right (cable, body and two prongs) as rounded rectangles that together fill
    /// `rect`, scaled to fit and centred when its aspect ratio isn't 1.5.
    public static func plug(in rect: IconRect) -> [IconRoundedRect] {
        // On a 15 × 10 grid.
        let unit = min(rect.width / 15, rect.height / 10)
        let originX = rect.midX - 7.5 * unit
        let originY = rect.midY - 5 * unit
        func part(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ radius: Double) -> IconRoundedRect {
            IconRoundedRect(
                rect: IconRect(
                    x: originX + x * unit, y: originY + y * unit, width: width * unit, height: height * unit),
                cornerRadius: radius * unit)
        }
        return [
            part(0, 4.1, 4.5, 1.8, 0.9),  // cable
            part(3.5, 1.5, 6.5, 7, 1.6),  // body
            part(9.5, 2.6, 5.5, 1.6, 0.8),  // upper prong
            part(9.5, 5.8, 5.5, 1.6, 0.8),  // lower prong
        ]
    }
}

/// Where each part of a drawn battery icon goes, in points at the menu bar's size. The app draws
/// it as is in the menu bar and scaled up in Settings.
///
/// Bars (``MenuBarIconStyle/modern``, ``MenuBarIconStyle/classic``,
/// ``MenuBarIconStyle/percentageInside``) fill ``fillArea`` from the left, clipped to its
/// rounded shape; the part of ``body`` right of the fill is the track. The ring fills clockwise
/// from the top.
public struct BatteryIconLayout: Sendable, Equatable {
    /// The whole icon.
    public var width: Double
    public var height: Double
    /// The battery's outer shape; for the ring, the circle's bounds including the stroke.
    public var body: IconRect
    public var cornerRadius: Double
    /// A stroke drawn inside the edge of ``body``; 0 for none.
    public var outlineWidth: Double
    /// Where the fill grows, and its corner radius.
    public var fillArea: IconRect
    public var fillCornerRadius: Double
    /// The empty part of the battery, in the label colour at this opacity; 0 leaves it clear.
    public var trackOpacity: Double
    /// The terminal at the right end.
    public var nub: IconRect?
    public var nubCornerRadius: Double
    public var nubOpacity: Double
    /// The ring's stroke width; 0 for the bars.
    public var ringLineWidth: Double
    /// The bolt or plug, if the state has one.
    public var glyph: IconRect?
    /// The clear outline knocked out around the glyph where it crosses the battery; 0 where the
    /// glyph crosses nothing.
    public var glyphGap: Double
    /// The charge number, drawn in bold rounded digits knocked out of the fill.
    public var digitsFontSize: Double?

    public var isRing: Bool { ringLineWidth > 0 }

    /// `nil` for ``MenuBarIconStyle/symbol``, which isn't drawn.
    public init?(style: MenuBarIconStyle, state: BatteryIconState) {
        let glyphAspect = BatteryIconGlyphs.aspectRatio(state.glyph)
        func glyphSize(boltHeight: Double, plugHeight: Double) -> (width: Double, height: Double) {
            let height = state.glyph == .bolt ? boltHeight : plugHeight
            return (height * glyphAspect, height)
        }
        glyphGap = 1
        digitsFontSize = nil
        ringLineWidth = 0
        outlineWidth = 0
        nubCornerRadius = 0.75
        switch style {
        case .symbol:
            return nil

        case .modern, .classic:
            // A 22 × 11 pt battery and a 1.5 × 4 pt terminal 1 pt to its right.
            body = IconRect(x: 0, y: 0, width: 22, height: 11)
            nub = IconRect(x: 23, y: 3.5, width: 1.5, height: 4)
            width = 24.5
            height = 11
            if style == .modern {
                cornerRadius = 5.5
                fillArea = body
                fillCornerRadius = cornerRadius
                trackOpacity = 0.35
                nubOpacity = 0.35
            } else {
                cornerRadius = 3
                outlineWidth = 1
                fillArea = body.insetBy(2)
                fillCornerRadius = 1.5
                trackOpacity = 0
                nubOpacity = 1
            }
            let size = glyphSize(boltHeight: 9.9, plugHeight: 6.6)
            glyph = state.glyph == .none ? nil : body.centered(width: size.width, height: size.height)

        case .percentageInside:
            // A little larger, so "100" fits; the bolt or plug goes after the terminal, since the
            // number fills the battery.
            body = IconRect(x: 0, y: 0, width: 24, height: 12)
            cornerRadius = 6
            fillArea = body
            fillCornerRadius = cornerRadius
            trackOpacity = 0.35
            nub = IconRect(x: 25, y: 4, width: 1.5, height: 4)
            nubOpacity = 0.35
            digitsFontSize = state.percent == nil ? nil : 9
            glyphGap = 0
            height = 12
            if state.glyph == .none {
                glyph = nil
                width = 26.5
            } else {
                let size = glyphSize(boltHeight: 10.2, plugHeight: 6.6)
                let box = IconRect(x: 28, y: (12 - size.height) / 2, width: size.width, height: size.height)
                glyph = box
                width = box.maxX
            }

        case .ring:
            body = IconRect(x: 0, y: 0, width: 13, height: 13)
            cornerRadius = 6.5
            ringLineWidth = 2
            fillArea = body
            fillCornerRadius = 0
            trackOpacity = 0.35
            nub = nil
            nubOpacity = 0
            width = 13
            height = 13
            // Inside the ring, clear of the stroke.
            glyphGap = 0
            let size = glyphSize(boltHeight: 7.15, plugHeight: 4.4)
            glyph = state.glyph == .none ? nil : body.centered(width: size.width, height: size.height)
        }
    }

    /// How far the fill reaches from ``fillArea``'s left edge, rounded to whole device pixels
    /// so the fill and the track meet on a crisp edge. Any charge above zero shows at least a
    /// pixel.
    public func fillWidth(level: Double, pixelScale: Double) -> Double {
        let level = min(1, max(0, level))
        guard level > 0, pixelScale > 0 else { return 0 }
        let pixels = max(1, (fillArea.width * level * pixelScale).rounded())
        return min(fillArea.width, pixels / pixelScale)
    }
}

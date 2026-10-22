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
        // `.toNearestOrEven`, as the formatter rounds the percentage beside the icon.
        let percent = s.chargePercent.map { Int(min(100, max(0, $0)).rounded(.toNearestOrEven)) }
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
        insetBy(dx: amount, dy: amount)
    }

    public func insetBy(dx: Double, dy: Double) -> IconRect {
        IconRect(x: x + dx, y: y + dy, width: width - dx * 2, height: height - dy * 2)
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

/// A size in icon coordinates.
public struct IconSize: Sendable, Equatable, Hashable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// The bolt and the plug drawn on the battery, as plain geometry.
public enum BatteryIconGlyphs {
    /// Width over height of a glyph's box.
    public static func aspectRatio(_ glyph: BatteryIconState.Glyph) -> Double {
        switch glyph {
        case .none: 1
        case .bolt: 0.7
        case .plug: 1.5
        }
    }

    /// The lightning bolt as a closed polygon filling `rect`, as macOS 27 draws it on its battery
    /// (best at a 0.7 aspect ratio; narrower boxes slant it more). It is point-symmetric about the
    /// centre, so it sits centred on the battery.
    public static func bolt(in rect: IconRect) -> [IconPoint] {
        // Fractions of the box: the top tip, down to the left notch, in, down to the bottom tip,
        // up to the right notch and back in.
        let grid: [(Double, Double)] = [(0.70, 0), (0, 0.58), (0.42, 0.58), (0.30, 1), (1, 0.42), (0.58, 0.42)]
        return grid.map { IconPoint(x: rect.x + $0.0 * rect.width, y: rect.y + $0.1 * rect.height) }
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
/// The sizes match the battery item of macOS 27, measured on 2x screenshots: a 23 × 12 pt body
/// with 4 pt corners, a 1.375 × 4 pt terminal 1 pt to its right, and a 14 pt bolt that overshoots
/// the body by 1 pt above and below. Every bar style shares one 26 × 14 pt canvas (whole points,
/// so the image is never resampled), and the status item doesn't change size between styles or
/// when the bolt appears.
///
/// Bars (``MenuBarIconStyle/modern``, ``MenuBarIconStyle/classic``,
/// ``MenuBarIconStyle/percentageInside``) fill ``fillArea`` from the left, clipped to its
/// rounded shape; the part of ``body`` right of the fill is the track. The ring fills clockwise
/// from the top.
public struct BatteryIconLayout: Sendable, Equatable {
    /// The number inside the battery and the bolt or plug next to it, knocked out of the battery
    /// (fill and track alike), so they keep one colour whatever is behind the icon.
    public struct Digits: Sendable, Equatable {
        /// Where the number and the glyph must fit, centred together.
        public var box: IconRect
        /// The height of the digits (the font's cap height); the font size follows from it.
        public var capHeight: Double
        /// The bolt or plug after the number, at full size; `nil` without one.
        public var glyphSize: IconSize?
        /// Between the end of the number (its advance) and the glyph.
        public var spacing: Double
        /// The widest pitch from one digit to the next, measured on the system's "99": a wider
        /// face is set closer (tracking), never narrowed, so the digits keep their shapes.
        public var maximumDigitAdvance: Double
        /// How much of the battery the number and the glyph take away: the system leaves a tenth.
        public var knockOut: Double

        /// Where the number goes when its `digitCount` digits advance `textWidth` points in all at
        /// ``capHeight``: set no wider than ``maximumDigitAdvance`` per digit, centred with the
        /// glyph in ``box``, and scaled down as a whole when they don't fit, as macOS does with
        /// "100", so nothing leaves the box and nothing is distorted.
        public func placement(textWidth: Double, digitCount: Int) -> DigitsPlacement {
            let textWidth = max(0, textWidth)
            let count = Double(max(1, digitCount))
            // Added after every digit but the last; never positive.
            let tracking = min(0, maximumDigitAdvance - textWidth / count)
            let setWidth = textWidth + tracking * (count - 1)
            let gap = glyphSize == nil ? 0 : spacing
            let natural = setWidth + gap + (glyphSize?.width ?? 0)
            let scale = natural > box.width ? box.width / natural : 1
            let height = capHeight * scale
            let text = IconRect(
                x: box.midX - natural * scale / 2, y: box.midY - height / 2, width: setWidth * scale, height: height)
            let glyph = glyphSize.map { size in
                IconRect(
                    x: text.maxX + gap * scale, y: box.midY - size.height * scale / 2, width: size.width * scale,
                    height: size.height * scale)
            }
            return DigitsPlacement(text: text, scale: scale, tracking: tracking * scale, glyph: glyph)
        }
    }

    /// The result of ``Digits/placement(textWidth:digitCount:)``.
    public struct DigitsPlacement: Sendable, Equatable {
        /// The number from its baseline (``IconRect/maxY``) to its cap height, and its width as set.
        public var text: IconRect
        /// How much the number and the glyph are scaled down to fit; 1 when they fit as they are.
        public var scale: Double
        /// Added after every digit but the last, in points as drawn (0 or less).
        public var tracking: Double
        /// The knocked-out bolt or plug.
        public var glyph: IconRect?
    }

    /// The whole icon.
    public var width: Double
    public var height: Double
    /// The battery's outer shape; for the ring, the circle's bounds including the stroke.
    public var body: IconRect
    /// Circular corners (the measured shape at this size; a continuous corner can't reach 4 pt
    /// on a 12 pt side).
    public var cornerRadius: Double
    /// A stroke drawn inside the edge of ``body``; 0 for none.
    public var outlineWidth: Double
    /// Where the fill grows, and its corner radius.
    public var fillArea: IconRect
    public var fillCornerRadius: Double
    /// The empty part of the battery, in the label colour at this opacity; 0 leaves it clear.
    public var trackOpacity: Double
    /// The terminal at the right end: flat against the battery, a half ellipse outside (the
    /// right half of an ellipse twice its width).
    public var nub: IconRect?
    public var nubOpacity: Double
    /// The ring's stroke width; 0 for the bars.
    public var ringLineWidth: Double
    /// The bolt or plug drawn over the battery, if the state has one (not with digits).
    public var glyph: IconRect?
    /// The clear outline knocked out around ``glyph`` where it crosses the battery; 0 where the
    /// glyph crosses nothing.
    public var glyphGap: Double
    /// The charge number, for ``MenuBarIconStyle/percentageInside`` with a reading.
    public var digits: Digits?

    public var isRing: Bool { ringLineWidth > 0 }

    /// The measured macOS 27 battery, shared by the bar styles.
    static let barBody = IconRect(x: 0, y: 1, width: 23, height: 12)
    static let barCornerRadius = 4.0
    static let barNub = IconRect(x: 24, y: 5, width: 1.375, height: 4)
    /// Whole points, so the rendered image has whole pixels at 1x and 2x and is never resampled.
    static let barSize = IconSize(width: 26, height: 14)
    /// The empty part and the terminal of the system item, measured: 0.48 and 0.58 of the label.
    static let trackOpacity = 0.48
    static let nubOpacity = 0.58

    /// `nil` for ``MenuBarIconStyle/symbol``, which isn't drawn.
    public init?(style: MenuBarIconStyle, state: BatteryIconState) {
        glyphGap = 1.2
        digits = nil
        ringLineWidth = 0
        outlineWidth = 0
        width = Self.barSize.width
        height = Self.barSize.height
        body = Self.barBody
        cornerRadius = Self.barCornerRadius
        nub = Self.barNub
        // The bolt overshoots the 12 pt body to the canvas's full 14 pt; the plug stays inside.
        let barGlyph: IconRect? =
            switch state.glyph {
            case .none: nil
            case .bolt: Self.barBody.centered(width: 14 * BatteryIconGlyphs.aspectRatio(.bolt), height: 14)
            case .plug: Self.barBody.centered(width: 7 * BatteryIconGlyphs.aspectRatio(.plug), height: 7)
            }
        switch style {
        case .symbol:
            return nil

        case .modern:
            fillArea = body
            fillCornerRadius = cornerRadius
            trackOpacity = Self.trackOpacity
            nubOpacity = Self.nubOpacity
            glyph = barGlyph

        case .classic:
            // The outlined battery of earlier macOS: a 1 pt outline and the fill 1 pt inside it.
            outlineWidth = 1
            fillArea = body.insetBy(2)
            fillCornerRadius = cornerRadius - 2
            trackOpacity = 0
            nubOpacity = 1
            glyph = barGlyph

        case .percentageInside:
            fillArea = body
            fillCornerRadius = cornerRadius
            trackOpacity = Self.trackOpacity
            nubOpacity = Self.nubOpacity
            if state.percent == nil {
                // Nothing to show inside: draw it like Modern.
                glyph = barGlyph
            } else {
                // Like macOS 27 with the percentage on: 7.4 pt digits and a small bolt 1 pt after
                // them, centred together, 2.3 pt clear of the top and bottom; "100" with a glyph is
                // scaled down to fit.
                glyph = nil
                glyphGap = 0
                let inline: IconSize? =
                    switch state.glyph {
                    case .none: nil
                    case .bolt: IconSize(width: 4.6, height: 7.4)
                    case .plug: IconSize(width: 7.5, height: 5)
                    }
                digits = Digits(
                    box: body.insetBy(dx: 1.5, dy: 2.3), capHeight: 7.4, glyphSize: inline, spacing: 1,
                    maximumDigitAdvance: 6.2, knockOut: 0.9)
            }

        case .ring:
            // As tall as the bar styles' canvas, with a 3 pt stroke so it reads at a glance.
            width = 14
            height = 14
            body = IconRect(x: 0, y: 0, width: 14, height: 14)
            cornerRadius = 7
            ringLineWidth = 3
            fillArea = body
            fillCornerRadius = 0
            trackOpacity = Self.trackOpacity
            nub = nil
            nubOpacity = 0
            // Inside the ring, clear of the stroke.
            glyphGap = 0
            glyph =
                switch state.glyph {
                case .none: nil
                case .bolt: body.centered(width: 6 * BatteryIconGlyphs.aspectRatio(.bolt), height: 6)
                case .plug: body.centered(width: 4 * BatteryIconGlyphs.aspectRatio(.plug), height: 4)
                }
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

    /// The size every style's preview takes in Settings (before magnification), so the tiles
    /// match: the bar styles' canvas; the ring and the SF Symbol are centred in it.
    public static let previewSize = barSize
}

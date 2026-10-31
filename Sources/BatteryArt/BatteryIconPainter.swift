#if os(macOS)
import BatteryCore
import CoreText
import SwiftUI

/// Paints a drawn battery icon (every style but the SF Symbol) from ``BatteryIconLayout``. The
/// decisions (state, colours, geometry) come from BatteryCore; this only turns them into paths.
public struct BatteryIconPainter: Sendable {
    let layout: BatteryIconLayout
    let state: BatteryIconState
    /// The menu bar's text colour; black for a template image.
    let label: Color
    /// Device pixels per layout point, so the fill ends on a pixel edge.
    let pixelScale: CGFloat

    public init(layout: BatteryIconLayout, state: BatteryIconState, label: Color, pixelScale: CGFloat) {
        self.layout = layout
        self.state = state
        self.label = label
        self.pixelScale = pixelScale
    }

    /// The label colour, or red when low and yellow in Low Power Mode.
    var fill: Color {
        switch state.tint {
        case .monochrome: label
        case .low: .red
        case .lowPower: .yellow
        }
    }

    public func paint(in context: inout GraphicsContext, magnification: CGFloat) {
        context.scaleBy(x: magnification, y: magnification)
        // A layer of its own, so the knocked-out parts never cut into what's behind the icon.
        context.drawLayer { layer in
            if layout.isRing {
                paintRing(in: &layer)
            } else {
                paintBar(in: &layer)
            }
            paintGlyph(in: &layer)
        }
    }

    // MARK: Parts

    private func paintBar(in context: inout GraphicsContext) {
        let fillEnd = layout.fillArea.x + layout.fillWidth(level: state.level, pixelScale: Double(pixelScale))
        if layout.trackOpacity > 0 {
            var track = context
            track.clip(to: Path(trailing(from: fillEnd)))
            track.opacity = layout.trackOpacity
            track.fill(rounded(layout.body, layout.cornerRadius), with: .color(label))
        }
        if fillEnd > layout.fillArea.x {
            var fillContext = context
            fillContext.clip(to: Path(leading(to: fillEnd)))
            fillContext.fill(rounded(layout.fillArea, layout.fillCornerRadius), with: .color(fill))
        }
        if layout.outlineWidth > 0 {
            let inset = layout.outlineWidth / 2
            context.stroke(
                rounded(layout.body.insetBy(inset), max(0, layout.cornerRadius - inset)),
                with: .color(label), lineWidth: CGFloat(layout.outlineWidth))
        }
        if let nub = layout.nub {
            var nubContext = context
            nubContext.opacity = layout.nubOpacity
            nubContext.clip(to: Path(cgRect(nub)))
            // The right half of an ellipse twice the terminal's width: flat against the battery.
            nubContext.fill(
                Path(ellipseIn: CGRect(x: nub.x - nub.width, y: nub.y, width: nub.width * 2, height: nub.height)),
                with: .color(label))
        }
        if let digits = layout.digits, let percent = state.percent {
            paintDigits(digits, percent: percent, in: &context)
        }
    }

    /// The number and the glyph after it, knocked out of the battery (fill and track alike) so they
    /// keep one colour. Built from the font's outlines: exact cap height and baseline, and nothing
    /// can leave the box the layout gives it.
    private func paintDigits(_ digits: BatteryIconLayout.Digits, percent: Int, in context: inout GraphicsContext) {
        guard let number = DigitOutlines(String(percent), capHeight: digits.capHeight) else { return }
        let placement = digits.placement(textWidth: number.width, digitCount: number.count)
        var path = number.path(in: placement.text, scale: placement.scale, tracking: placement.tracking)
        if let box = placement.glyph {
            path.addPath(glyphPath(in: box))
        }
        var knockOut = context
        knockOut.blendMode = .destinationOut
        // The system leaves a tenth of the battery under the number.
        knockOut.opacity = digits.knockOut
        knockOut.fill(path, with: .color(.black))
    }

    /// The bold system font's digits (SF Pro Bold, default proportional figures) as Core Text
    /// outlines, at the size whose cap height is `capHeight`. Made for each render, which happens
    /// once per state change.
    private struct DigitOutlines {
        let font: CTFont
        let glyphs: [CGGlyph]
        let advances: [CGSize]
        /// The number's advance, in points.
        let width: Double
        var count: Int { glyphs.count }

        /// `nil` when Core Text has no system font or no glyph for a character; the number is then
        /// not drawn.
        init?(_ string: String, capHeight: Double) {
            guard let reference = CTFontCreateUIFontForLanguage(.emphasizedSystem, 100, nil) else { return nil }
            let referenceCapHeight = CTFontGetCapHeight(reference)
            guard referenceCapHeight > 0,
                let font = CTFontCreateUIFontForLanguage(
                    .emphasizedSystem, CGFloat(capHeight) * 100 / referenceCapHeight, nil)
            else { return nil }
            let characters = Array(string.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            guard CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count) else { return nil }
            var advances = [CGSize](repeating: .zero, count: glyphs.count)
            width = CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
            self.font = font
            self.glyphs = glyphs
            self.advances = advances
        }

        /// The baseline on `rect.maxY` and the first digit's origin at `rect.x`, scaled by `scale`,
        /// with `tracking` (points as drawn) after every digit.
        func path(in rect: IconRect, scale: Double, tracking: Double) -> Path {
            let outline = CGMutablePath()
            var x = rect.x
            for (glyph, advance) in zip(glyphs, advances) {
                if let glyphOutline = CTFontCreatePathForGlyph(font, glyph, nil) {
                    // Core Text is y up: flip it and put the baseline on rect.maxY.
                    let transform = CGAffineTransform(
                        a: CGFloat(scale), b: 0, c: 0, d: CGFloat(-scale), tx: CGFloat(x), ty: CGFloat(rect.maxY))
                    outline.addPath(glyphOutline, transform: transform)
                }
                x += Double(advance.width) * scale + tracking
            }
            return Path(outline)
        }
    }

    private func paintRing(in context: inout GraphicsContext) {
        let circle = cgRect(layout.body.insetBy(layout.ringLineWidth / 2))
        let ring = Path(ellipseIn: circle)
        var track = context
        track.opacity = layout.trackOpacity
        track.stroke(ring, with: .color(label), lineWidth: CGFloat(layout.ringLineWidth))
        guard state.level > 0 else { return }
        // The ellipse starts at three o'clock; turn it to start at the top and run clockwise.
        let rotation = CGAffineTransform(translationX: circle.midX, y: circle.midY)
            .rotated(by: -.pi / 2)
            .translatedBy(x: -circle.midX, y: -circle.midY)
        context.stroke(
            ring.trimmedPath(from: 0, to: CGFloat(state.level)).applying(rotation),
            with: .color(fill), style: StrokeStyle(lineWidth: CGFloat(layout.ringLineWidth), lineCap: .round))
    }

    /// The bolt or plug in the label colour, with a thin gap knocked out around it so it stays
    /// visible where it crosses the fill.
    private func paintGlyph(in context: inout GraphicsContext) {
        guard let box = layout.glyph else { return }
        let path = glyphPath(in: box)
        // A zero line width would still stroke a hairline.
        if layout.glyphGap > 0 {
            var knockOut = context
            knockOut.blendMode = .destinationOut
            knockOut.stroke(
                path, with: .color(.black),
                style: StrokeStyle(lineWidth: CGFloat(layout.glyphGap * 2), lineJoin: .round))
            knockOut.fill(path, with: .color(.black))
        }
        context.fill(path, with: .color(label))
    }

    private func glyphPath(in box: IconRect) -> Path {
        var path = Path()
        switch state.glyph {
        case .none:
            break
        case .bolt:
            path.addLines(BatteryIconGlyphs.bolt(in: box).map { CGPoint(x: $0.x, y: $0.y) })
            path.closeSubpath()
        case .plug:
            for part in BatteryIconGlyphs.plug(in: box) {
                path.addRoundedRect(
                    in: cgRect(part.rect), cornerSize: CGSize(width: part.cornerRadius, height: part.cornerRadius))
            }
        }
        return path
    }

    // MARK: Geometry

    private func cgRect(_ rect: IconRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    /// Circular corners, the shape measured on the system's battery (exact half circles when the
    /// radius reaches half the side).
    private func rounded(_ rect: IconRect, _ radius: Double) -> Path {
        Path(
            roundedRect: cgRect(rect), cornerRadius: CGFloat(min(radius, min(rect.width, rect.height) / 2)),
            style: .circular)
    }

    /// Everything left of `x`, with room to spare around the icon.
    private func leading(to x: Double) -> CGRect {
        CGRect(x: -1, y: -1, width: x + 1, height: layout.height + 2)
    }

    /// Everything right of `x`.
    private func trailing(from x: Double) -> CGRect {
        CGRect(x: x, y: -1, width: layout.width + 1 - x, height: layout.height + 2)
    }
}

/// A drawn battery icon at `magnification` times its menu bar size.
public struct BatteryIconCanvas: View {
    let layout: BatteryIconLayout
    let state: BatteryIconState
    var label: Color = .primary
    var magnification: CGFloat = 1
    /// The device scale to align the fill to; the display's when `nil`.
    var pixelScale: CGFloat?
    @Environment(\.displayScale) private var displayScale

    public init(
        layout: BatteryIconLayout, state: BatteryIconState, label: Color = .primary, magnification: CGFloat = 1,
        pixelScale: CGFloat? = nil
    ) {
        self.layout = layout
        self.state = state
        self.label = label
        self.magnification = magnification
        self.pixelScale = pixelScale
    }

    public var body: some View {
        let factor = magnification
        let painter = BatteryIconPainter(
            layout: layout, state: state, label: label, pixelScale: (pixelScale ?? displayScale) * factor)
        Canvas { context, _ in
            painter.paint(in: &context, magnification: factor)
        }
        .frame(width: CGFloat(layout.width) * magnification, height: CGFloat(layout.height) * magnification)
        .accessibilityHidden(true)
    }
}
#endif

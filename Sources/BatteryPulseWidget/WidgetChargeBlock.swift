#if os(macOS)
import BatteryArt
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// The charge block: the visual (the level symbol, a ring or the drawn battery), the main value and
/// the lines under it. When it fills its place, as in small and medium, the visual sits at the top
/// and the number and lines at the bottom, as in 0.6.x; above large's and extra large's details it
/// takes its own height.
///
/// VoiceOver reads the charge as one element, "Battery charge: 70 %, On battery", from the visual
/// and, when the main value is the charge, the number with it; another main value is an element of
/// its own after it. The state line is in the charge's element, so VoiceOver skips the line itself.
struct WidgetChargeBlock: View {
    let layout: BatteryWidgetLayout
    let size: WidgetSize
    /// Fill the place, with the number at the bottom.
    var fills = true
    @Environment(\.widgetStrings) private var strings

    /// Small and medium keep 0.6.x's sizes; large and extra large have room for more.
    private var roomy: Bool { size != .small && size != .medium }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch layout.visual {
            case .symbol, .drawnBattery: stacked
            case .ring: ring
            }
            ForEach(Array(layout.lines.enumerated()), id: \.offset) { _, line in
                WidgetLineView(line: line, tinted: layout.tinted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
    }

    /// The visual above the main value.
    @ViewBuilder private var stacked: some View {
        if let mainLabel = layout.mainLabel {
            VStack(alignment: .leading, spacing: 4) {
                visual.widgetElement(layout.chargeLabel, strings: strings)
                if fills { Spacer(minLength: 0) }
                WidgetHeroNumber(main: layout.main, tinted: layout.tinted, size: roomy ? 40 : 34)
                    .widgetElement(mainLabel, strings: strings)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                visual
                if fills { Spacer(minLength: 0) }
                WidgetHeroNumber(main: layout.main, tinted: layout.tinted, size: roomy ? 40 : 34)
            }
            .widgetElement(layout.chargeLabel, strings: strings)
        }
    }

    /// The level symbol or the drawn battery, and the symbol of a level that isn't normal.
    private var visual: some View {
        HStack(spacing: 4) {
            switch layout.visual {
            case .drawnBattery:
                WidgetDrawnBattery(level: layout.level, tinted: layout.tinted, magnification: roomy ? 2.5 : 2)
            case .symbol, .ring:
                WidgetLevelSymbol(level: layout.level, tinted: layout.tinted)
                    .font(roomy ? .title : .title2)
            }
            if let cue = layout.level.cue {
                WidgetCueSymbol(cue: cue, tinted: layout.tinted)
            }
        }
    }

    /// The main value inside a ring of the charge.
    @ViewBuilder private var ring: some View {
        let diameter: CGFloat = roomy ? 92 : 84
        let lineWidth: CGFloat = roomy ? 8 : 7
        let value = WidgetHeroNumber(main: layout.main, tinted: layout.tinted, size: roomy ? 25 : 22)
            .lineLimit(1)
            .padding(.horizontal, lineWidth + 4)
        HStack(alignment: .top, spacing: 4) {
            Group {
                if let mainLabel = layout.mainLabel {
                    ZStack {
                        WidgetRing(level: layout.level, tinted: layout.tinted, lineWidth: lineWidth)
                            .widgetElement(layout.chargeLabel, strings: strings)
                        value.widgetElement(mainLabel, strings: strings)
                    }
                } else {
                    ZStack {
                        WidgetRing(level: layout.level, tinted: layout.tinted, lineWidth: lineWidth)
                        value
                    }
                    .widgetElement(layout.chargeLabel, strings: strings)
                }
            }
            .frame(width: diameter, height: diameter)
            // A level that isn't normal says so beside the ring too, so its colour is never the
            // only signal.
            if let cue = layout.level.cue {
                WidgetCueSymbol(cue: cue, tinted: layout.tinted)
            }
        }
        if fills { Spacer(minLength: 0) }
    }
}

/// The value the widget shows large, with the symbol of a tier that isn't normal beside it.
struct WidgetHeroNumber: View {
    let main: WidgetMainValue
    let tinted: Bool
    /// The number's point size: the hero number keeps its size whatever the text size, as in 0.6.x.
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // WidgetKit animates from one timeline entry to the next by itself; this says how the
        // number changes. Nothing runs between entries.
        let number = Text(verbatim: main.text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .contentTransition(reduceMotion ? .opacity : .numericText(value: main.number))
        if let cue = main.cue {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                number
                WidgetCueSymbol(cue: cue, tinted: tinted)
            }
        } else {
            number
        }
    }
}

/// The level symbol of 0.6.x, the glyph of the widget: in the level's colour in full colour, and
/// in the accented mode the accent's, which macOS draws white.
struct WidgetLevelSymbol: View {
    let level: WidgetLevel
    let tinted: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        decorativeSymbol(level.symbolName, accentedMode: .accented)
            .foregroundStyle(renderingMode == .fullColor && tinted ? level.tier.color : .primary)
            .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
    }
}

/// The charge as a ring: a plain trimmed circle, with no gauge, animation or glass. Its arc is the
/// glyph (the accent group); the track is a hierarchical style in every mode but full colour.
struct WidgetRing: View {
    let level: WidgetLevel
    let tinted: Bool
    let lineWidth: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let coloured = renderingMode == .fullColor && tinted
        ZStack {
            Circle()
                .stroke(
                    coloured ? AnyShapeStyle(level.tier.color.opacity(0.25)) : AnyShapeStyle(.quaternary),
                    lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, level.percent / 100)))
                .stroke(
                    coloured ? AnyShapeStyle(level.tier.color) : AnyShapeStyle(.primary),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                // From the top, clockwise.
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .padding(lineWidth / 2)
    }
}

/// The charge as the menu bar's Modern battery, drawn by the app's own painter at `magnification`
/// times its menu bar size: the level's colour in full colour, the primary style otherwise, with
/// the bolt while charging and the plug on power. It is the glyph, in the accent group.
struct WidgetDrawnBattery: View {
    let level: WidgetLevel
    let tinted: Bool
    let magnification: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if let layout = BatteryIconLayout(style: .modern, state: level.icon) {
            BatteryIconCanvas(
                layout: layout, state: level.icon,
                label: renderingMode == .fullColor && tinted ? level.tier.color : .primary,
                magnification: magnification
            )
            .widgetAccentable()
        }
    }
}
#endif

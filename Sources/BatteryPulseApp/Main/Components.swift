#if os(macOS)
import BatteryCore
import SwiftUI

// Content-layer building blocks. Per Apple's Liquid Glass guidance, glass belongs to the
// navigation and control layer (sidebar, toolbar, controls), which SwiftUI provides; content
// uses standard fills, and nothing inside a card ever gets glass. How a group is drawn follows
// the window style (`\.windowLook`): a card in Standard, a faint frost layer in Frosted, and on
// Translucent's and Clear's glass sheet no surface at all, with hairlines between the groups,
// bold numbers and medium text instead.
//
// Motion: values that change with the 2 s readings (watts, mA, mV, °C, mAh) change instantly.
// Only discrete events animate, through `\.motion`: the whole percent, the level tier, plugging in
// or out, the charge state, the battery symbol and the direction of the power flow.

/// A rounded section of a page (Overview, History, a device, the compact window): a standard
/// fill in Standard, one faint lighter layer on Frosted's frost.
struct Card<Content: View>: View {
    private let title: LocalizedStringKey?
    private let content: Content
    @Environment(\.windowLook) private var look

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let stack = VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(look.boldNumerals ? .headline.weight(.bold) : .headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        switch look.groupSurface {
        case .card:
            stack.background(.background.secondary, in: .rect(cornerRadius: 16, style: .continuous))
        case .frostLayer:
            stack.background { FrostLayer(cornerRadius: 16) }
        case .none:
            stack
                .modifier(GroupRule())
                .contentTreatment()
        }
    }
}

extension View {
    /// Clear's treatment under a group of white content (a card, a Form row): one composited
    /// group with a tight shadow and a soft halo, so the white reads over a bright desktop.
    /// Nothing in the other styles, and nothing again inside a group that has it.
    func contentTreatment() -> some View {
        modifier(ContentTreatmentModifier())
    }
}

private struct ContentTreatmentModifier: ViewModifier {
    @Environment(\.contentTreatment) private var treatment

    @ViewBuilder
    func body(content: Content) -> some View {
        if let treatment {
            content
                .environment(\.contentTreatment, nil)
                .compositingGroup()
                .shadow(
                    color: .black.opacity(treatment.shadowOpacity), radius: treatment.shadowRadius,
                    y: treatment.shadowOffsetY
                )
                .shadow(color: .black.opacity(treatment.haloOpacity), radius: treatment.haloRadius)
        } else {
            content
        }
    }
}

/// Clear's warning: a solid white capsule with dark text and a symbol, as the clear Home Screen
/// turns red badges white. The most legible mark on the glass, so it needs no colour; VoiceOver
/// reads its text.
struct InvertedBadge: View {
    let text: Text

    var body: some View {
        Label {
            text
        } icon: {
            Image(systemName: ToneBadge.symbolName)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color(white: ToneMap.ink))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.white.opacity(0.95), in: .capsule)
    }
}

/// On the glass sheet, the hairline above a group, halfway into the gap above it. The group at
/// the top of its ``CardGroup`` has none.
private struct GroupRule: ViewModifier {
    @Environment(\.tones) private var tones
    @Environment(\.displayScale) private var displayScale
    @State private var isBelowTop = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isBelowTop {
                    Rectangle()
                        .fill(tones.style(.hairline))
                        .frame(height: 1 / displayScale)
                        .offset(y: -8)
                        .accessibilityHidden(true)
                }
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: NamedCoordinateSpace.named(CardGroupSpace.name)).minY > 1
            } action: { isBelowTop in
                self.isBelowTop = isBelowTop
            }
    }
}

/// The coordinate space a ``CardGroup`` names, so its groups know which one is at the top.
private enum CardGroupSpace {
    static let name = "cardGroup"
}

/// On the glass sheet, text levels come from the tone map: no tertiary text (it uses the secondary
/// level), and in Clear white at fixed opacities.
private struct SheetTextLevels: ViewModifier {
    let tones: ToneMap

    func body(content: Content) -> some View {
        content.foregroundStyle(
            tones.style(.text(.primary)), tones.style(.text(.secondary)), tones.style(.text(.tertiary)))
    }
}

extension View {
    /// Content that sits straight on the glass sheet, outside a ``Card`` and a ``LookForm`` (the
    /// Raw Data table, a page's empty state, a footnote): the sheet's text levels and Clear's
    /// treatment, as one group. Nothing in the other styles.
    func sheetContent() -> some View {
        modifier(SheetContentModifier())
    }
}

private struct SheetContentModifier: ViewModifier {
    @Environment(\.windowLook) private var look
    @Environment(\.tones) private var tones

    @ViewBuilder
    func body(content: Content) -> some View {
        if look.usesGlassSheet {
            content
                .modifier(SheetTextLevels(tones: tones))
                .contentTreatment()
        } else {
            content
        }
    }
}

/// Frosted's group surface: one faint, lighter layer with a hairline rim on the frosted window,
/// like the banner of the macOS widget gallery. A plain fill, not a second material: the frost
/// behind it is already blurred, and a material on a material only adds a blur pass.
struct FrostLayer: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark
        shape
            .fill(.white.opacity(isDark ? 0.06 : 0.30))
            .overlay { shape.strokeBorder(.white.opacity(isDark ? 0.18 : 0.59), lineWidth: 0.5) }
    }
}

/// A page's stack of cards. On the glass sheet it sets the text levels and names the space in
/// which each group finds out whether it is the top one.
struct CardGroup<Content: View>: View {
    private let content: Content
    @Environment(\.windowLook) private var look
    @Environment(\.tones) private var tones

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if look.usesGlassSheet {
            content
                .coordinateSpace(NamedCoordinateSpace.named(CardGroupSpace.name))
                .modifier(SheetTextLevels(tones: tones))
        } else {
            content
        }
    }
}

/// A page's grouped Form (Power, Health, Demo Mode, the Raw Data inspector). In the see-through
/// styles it hides its own background, so the window's shows; the sections keep the system's
/// fill on Frosted, where they read as lighter layers, and drop it on the glass sheet, where the
/// rows' separators are the only lines.
struct LookForm<Content: View>: View {
    private let content: Content
    @Environment(\.windowLook) private var look
    @Environment(\.tones) private var tones

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let form = Form {
            // A Group hands the row background to each section, and each section to its rows.
            Group {
                content
            }
            .listRowBackground(look.clearsFormRows ? Color.clear : nil)
        }
        .formStyle(.grouped)
        .scrollContentBackground(look.hidesFormBackground ? .hidden : .automatic)
        if look.usesGlassSheet {
            form.modifier(SheetTextLevels(tones: tones))
        } else {
            form
        }
    }
}

/// A ring-shaped gauge (the built-in circular style is watchOS-only).
struct RingGaugeStyle: GaugeStyle {
    var tint: Color
    var diameter: CGFloat = 112
    var lineWidth: CGFloat = 11

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RingTrack(lineWidth: lineWidth)
            RingArc(value: configuration.value, tint: tint, lineWidth: lineWidth)
            RingLabels(value: configuration.currentValueLabel, label: configuration.label)
                // Keep the text inside the ring: roughly the square inscribed in its inner edge,
                // so long labels (Russian ones especially) wrap instead of running into the stroke.
                .frame(maxWidth: (diameter - lineWidth) * 0.74)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The value and the title inside a ring; bold and medium on the glass sheet.
private struct RingLabels<Value: View, Title: View>: View {
    let value: Value
    let label: Title
    @Environment(\.windowLook) private var look

    var body: some View {
        VStack(spacing: 2) {
            value
                .font(.title2.weight(look.boldNumerals ? .bold : .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            label
                .font(look.boldNumerals ? .caption.weight(.medium) : .caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

/// The channel under the ring's arc.
private struct RingTrack: View {
    let lineWidth: CGFloat
    @Environment(\.tones) private var tones

    var body: some View {
        Circle()
            .stroke(tones.style(.track), lineWidth: lineWidth)
    }
}

/// The ring's coloured arc, a view of its own so it can read `\.motion`. In Clear it is a white
/// glass piece, whatever the tint.
private struct RingArc: View {
    let value: Double
    let tint: Color
    let lineWidth: CGFloat
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones

    var body: some View {
        let fraction = max(0.001, min(1, value))
        let arc = Circle().trim(from: 0, to: fraction)
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        Group {
            // The colour styles keep the tint itself, so a new tier still crossfades.
            if let piece = tones.levelPieceStyle {
                arc.stroke(piece, style: stroke)
            } else {
                arc.stroke(tint, style: stroke)
            }
        }
        .rotationEffect(.degrees(-90))
        // The arc grows or shrinks to a new value (a whole percent, a cycle, maximum capacity)
        // and crossfades to a new tier colour. A built-in animatable shape: no body per frame.
        // Under Reduce Motion the arc snaps and only the colour fades; the inner modifier
        // wins when both change at once, so the arc never sweeps then.
        .animation(motion.change, value: fraction)
        .animation(motion.crossfade, value: tint)
        // Where the ring sits is the page's business: when the page's layout changes in the
        // same update, the arc moves with the track, not with its own animation.
        .geometryGroup()
    }
}

/// Gauge tile used on the Overview: a ring with a caption underneath.
struct GaugeTile: View {
    let title: LocalizedStringKey
    let fraction: Double
    let value: String
    /// The number `value` shows (a percentage, a cycle count), so it rolls in the direction of a
    /// change.
    var number: Double?
    let caption: String?
    var captionHelp: String?
    let tint: Color
    /// Clear's warning badge, shown in place of the caption: the words of a low or critical tier.
    var badge: String?

    var body: some View {
        Card {
            VStack(spacing: 10) {
                Gauge(value: fraction) {
                    Text(title)
                } currentValueLabel: {
                    Text(value)
                        .numericValue(number)
                }
                .gaugeStyle(RingGaugeStyle(tint: tint))
                if let badge {
                    InvertedBadge(text: Text(badge))
                } else if let caption {
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .help(captionHelp ?? "")
                }
            }
            // Fill the row's height, so tiles stay equal when one caption wraps.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// A battery drawn to the exact level, with a bolt while charging. Used by the Overview, the
/// compact window and the menu bar panel.
///
/// The fill follows a new whole percent and crossfades to a new tier colour; the bolt draws in
/// when charging starts and goes when it stops. In Clear the fill is a white glass piece and the
/// bolt over it dark.
struct BatteryGlyph: View {
    let level: Double
    let isCharging: Bool
    let tint: Color
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones

    var body: some View {
        // The fill animates per whole percent, the step the app shows.
        let wholePercent = (level * 100).rounded()
        GeometryReader { geometry in
            let height = geometry.size.height
            let terminalWidth = height * 0.12
            let bodyWidth = geometry.size.width - terminalWidth - height * 0.04
            let inset = height * 0.1
            let fillWidth = max(0, (bodyWidth - inset * 2) * min(1, max(0, level)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.24, style: .continuous)
                    .strokeBorder(.secondary, lineWidth: max(2, height * 0.06))
                    .frame(width: bodyWidth)
                let fill = RoundedRectangle(cornerRadius: height * 0.15, style: .continuous)
                Group {
                    if let piece = tones.levelPieceStyle {
                        fill.fill(piece)
                    } else {
                        fill.fill(tint.gradient)
                    }
                }
                .frame(width: fillWidth, height: height - inset * 2)
                .padding(.leading, inset)
                RoundedRectangle(cornerRadius: terminalWidth / 2, style: .continuous)
                    .fill(.secondary)
                    .frame(width: terminalWidth, height: height * 0.36)
                    .offset(x: bodyWidth + height * 0.04)
                if isCharging {
                    // Primary over the empty part of the battery, white over the fill (dark over
                    // Clear's white fill), so the bolt stays visible at any level in Light and
                    // Dark Mode.
                    let bolt = Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.5, weight: .bold))
                        .frame(width: bodyWidth)
                    // One view, so both copies draw in and out together.
                    ZStack {
                        bolt
                            .foregroundStyle(.primary)
                        bolt
                            .foregroundStyle(tones.style(.onLevelFill))
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: inset + fillWidth)
                            }
                    }
                    .transition(motion.boltTransition)
                }
            }
            // Scoped to the glyph, which shows nothing that changes with the live readings. The
            // white bolt's mask moves with the fill. The fill moves, so under Reduce Motion it
            // snaps (the innermost modifier wins when several values change at once); the tint
            // and the bolt only fade.
            .animation(motion.change, value: wholePercent)
            .animation(motion.crossfade, value: tint)
            .animation(motion.crossfade, value: isCharging)
        }
        .aspectRatio(2.2, contentMode: .fit)
        // The glyph's place on the page follows the page's animation, not the ones above: a new
        // tint in the same update as a layout change doesn't slide the glyph.
        .geometryGroup()
        .accessibilityHidden(true)
    }
}

/// Horizontal capacity bars: remaining, full and design mAh on one scale.
struct CapacityBars: View {
    let bars: [CapacityBar]
    let formatter: BatteryFormatter
    @Environment(\.tones) private var tones
    @Environment(\.windowLook) private var look

    init(snapshot: BatterySnapshot, formatter: BatteryFormatter) {
        self.init(bars: CapacityBar.bars(for: snapshot), formatter: formatter)
    }

    /// Bars from any battery, such as an iPhone's.
    init(bars: [CapacityBar], formatter: BatteryFormatter) {
        self.bars = bars
        self.formatter = formatter
    }

    var body: some View {
        let scale = CapacityBar.scale(of: bars)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            // Identified by kind, so a bar that appears or goes away is that bar, not the last
            // row. The mAh values change every few readings and are not animated.
            ForEach(bars) { bar in
                GridRow {
                    Text(bar.kind.title)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(bar.capacityMAh), total: scale)
                        .tint(tones.color(.capacity(bar.kind)))
                        .gridColumnAlignment(.leading)
                    Text(formatter.milliampHours(bar.capacityMAh))
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                        .fontWeight(look.boldNumerals ? .bold : nil)
                }
            }
        }
    }
}

extension CapacityBar.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .remaining: "Remaining"
        case .fullCharge: "Full charge"
        case .design: "Design"
        }
    }
}

/// Where the power goes: adapter → Mac → battery (or battery → Mac on battery power).
///
/// Events animate, the watts don't: the adapter slides in and out when plugging in or out, the
/// battery arrow turns when the power flow changes direction, the battery symbol swaps at a new
/// level or charge state and bounces once on reaching full. Under Reduce Motion the adapter
/// fades while the other nodes snap to their new places, and the symbols crossfade.
struct PowerFlowView: View {
    let snapshot: BatterySnapshot
    let formatter: BatteryFormatter
    @Environment(\.motion) private var motion
    /// Counts the times the battery reached full while this view was shown; each change plays one
    /// bounce of the battery symbol.
    @State private var fullCount = 0

    var body: some View {
        let key = BatteryMotionKey(snapshot)
        let showsAdapter = snapshot.isExternalPowerConnected == true && snapshot.adapter != nil
        HStack(alignment: .center, spacing: 0) {
            if showsAdapter, let adapter = snapshot.adapter {
                node(title: "Adapter", value: adapter.watts.map { formatter.watts(Double($0), fractionDigits: 0) }) {
                    Image(systemName: "powerplug.portrait.fill")
                }
                .transition(motion.insertion(edge: .leading))
                arrow(
                    value: snapshot.systemPowerInWatts.flatMap { $0 > 0 ? formatter.watts($0) : nil },
                    pointsRight: true
                )
                .transition(motion.insertion(edge: .leading))
            }
            node(title: "Mac", value: snapshot.systemLoadWatts.map { formatter.watts($0) }) {
                Image(systemName: "laptopcomputer")
            }
            // The direction and the hidden value share `BatteryMotionKey.flow` and its dead band,
            // so noise around 0 W neither turns the arrow nor shows a value.
            arrow(
                value: key.flow == .idle ? nil : snapshot.batteryPowerWatts.map { formatter.watts(abs($0)) },
                pointsRight: key.batteryArrowPointsIntoBattery)
            node(title: "Battery", value: snapshot.chargePercent.map { formatter.percent($0) }) {
                Image(systemName: key.symbolName)
                    .contentTransition(motion.symbolSwap)
                    .symbolEffect(.bounce, options: .nonRepeating, value: fullCount)
                    .animation(motion.crossfade, value: key.symbolName)
                    .geometryGroup()
            }
        }
        .frame(maxWidth: .infinity)
        // The adapter slides in from the card's edge, not from beyond it.
        .clipped()
        // The nodes move to make room for the adapter: no animation under Reduce Motion.
        .animation(motion.change, value: showsAdapter)
        .onChange(of: key.chargeState) { old, new in
            // A one-off extra: not under Reduce Motion or Low Power Mode, nor in a hidden window.
            if BatteryMotionKey.reachedFull(from: old, to: new), motion.allowsFlourish {
                fullCount += 1
            }
        }
    }

    private func node<Symbol: View>(
        title: LocalizedStringKey, value: String?, @ViewBuilder symbol: () -> Symbol
    ) -> some View {
        VStack(spacing: 6) {
            symbol()
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(.fill.tertiary, in: .circle)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
        .frame(minWidth: 90)
    }

    private func arrow(value: String?, pointsRight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value ?? " ")
                .font(.caption.weight(.medium))
                .monospacedDigit()
            Image(systemName: pointsRight ? "arrow.right" : "arrow.left")
                .font(.title3)
                .foregroundStyle(value == nil ? .tertiary : .secondary)
                .contentTransition(motion.symbolSwap)
                .animation(motion.crossfade, value: pointsRight)
                // The symbol crossfades in place; where the arrow sits follows the row's own
                // animation, so it doesn't slide under Reduce Motion when the adapter comes and
                // the direction turns in the same update.
                .geometryGroup()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }
}

/// A Form row with a label and a monospaced value; medium weight on the glass sheet.
struct ValueRow: View {
    let label: LocalizedStringKey
    let value: String
    @Environment(\.windowLook) private var look

    init(_ label: LocalizedStringKey, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .monospacedDigit()
                .textSelection(.enabled)
        }
        .fontWeight(look.boldNumerals ? .medium : nil)
        .contentTreatment()
    }
}
#endif

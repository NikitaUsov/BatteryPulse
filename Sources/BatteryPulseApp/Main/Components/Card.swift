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
private struct FrostLayer: View {
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
#endif

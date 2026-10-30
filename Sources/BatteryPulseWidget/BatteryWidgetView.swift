#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// Reads the widget's family and hands the views its size: `\.widgetFamily` can only be read, so
/// the views take the size as an input, which a preview can set.
struct BatteryWidgetRoot: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BatteryWidgetView(entry: entry, size: WidgetSize(family))
    }
}

extension WidgetSize {
    /// The size of a family the widget declares; any other draws as small, the smallest place.
    init(_ family: WidgetFamily) {
        switch family {
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        case .systemExtraLarge: self = .extraLarge
        default: self = .small
        }
    }
}

/// One entry of the Battery widget, as ``WidgetLayoutPlan`` lays it out for the size. One
/// `widgetURL` opens the page about the main value, or the one that fixes an empty state.
///
/// - Small: the charge block alone, as in 0.6.x.
/// - Medium: the charge block and, beside it, the details, as in 0.6.x.
/// - Large: the charge block, then the details in two columns of tiles.
/// - Extra large: two panels, Battery (the charge block and its details) and Power.
struct BatteryWidgetView: View {
    let entry: BatteryEntry
    let size: WidgetSize
    var formatter = BatteryFormatter.widget
    var timeZone = TimeZone.autoupdatingCurrent

    var body: some View {
        let plan = WidgetLayoutPlan.make(
            size: size, configuration: entry.configuration, snapshot: entry.snapshot, entry: entry.moment,
            formatter: formatter, timeZone: timeZone)
        Group {
            switch plan {
            case .battery(let layout):
                switch size {
                case .small:
                    WidgetChargeBlock(layout: layout, size: size)
                case .medium:
                    if layout.details.isEmpty {
                        WidgetChargeBlock(layout: layout, size: size)
                    } else {
                        HStack(spacing: 16) {
                            WidgetChargeBlock(layout: layout, size: size)
                            Divider()
                            WidgetDetailList(details: layout.details, tinted: layout.tinted)
                        }
                    }
                case .large:
                    WidgetLargeLayout(layout: layout)
                case .extraLarge, .extraLargePortrait:
                    WidgetExtraLargeLayout(layout: layout, size: size)
                }
            case .empty(let reason):
                WidgetEmptyState(reason: reason)
            }
        }
        .widgetURL(plan.route.url)
    }
}

/// Large: the charge block at the top and the details below it, in two columns of tiles.
struct WidgetLargeLayout: View {
    let layout: BatteryWidgetLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetChargeBlock(layout: layout, size: .large, fills: layout.details.isEmpty)
            if !layout.details.isEmpty {
                Spacer(minLength: 0)
                Divider()
                WidgetTileGrid(details: layout.details, tinted: layout.tinted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Extra large: two panels side by side. Battery holds the charge block and its details, Power
/// the rest, headed by its first detail drawn large; both grids of tiles sit at the bottom, level
/// with each other. Automatic names the panels; Custom's hold whatever was chosen, so they go
/// unnamed, and without details for the Power panel the Battery panel takes the whole width.
struct WidgetExtraLargeLayout: View {
    let layout: BatteryWidgetLayout
    let size: WidgetSize

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                if layout.panelHeadings {
                    WidgetPanelHeading(panel: .battery)
                }
                WidgetChargeBlock(layout: layout, size: size, fills: layout.details.isEmpty)
                if !layout.details.isEmpty {
                    Spacer(minLength: 0)
                    WidgetTileGrid(details: layout.details, tinted: layout.tinted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if !layout.powerDetails.isEmpty {
                let power = WidgetHeroDetail.split(layout.powerDetails)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    if layout.panelHeadings {
                        WidgetPanelHeading(panel: .power)
                    }
                    if let hero = power.hero {
                        WidgetHeroDetail(row: hero.row, text: hero.text, tinted: layout.tinted)
                    }
                    Spacer(minLength: 0)
                    WidgetTileGrid(details: power.rest, tinted: layout.tinted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

/// An extra-large panel's name, a heading for VoiceOver.
struct WidgetPanelHeading: View {
    enum Panel {
        case battery, power
    }

    let panel: Panel
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        title
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }

    private var title: Text {
        switch panel {
        case .battery: Text("Battery", bundle: strings)
        case .power: Text("Power", bundle: strings)
        }
    }
}

/// The message of a widget without a battery to show: one VoiceOver element, the message.
struct WidgetEmptyState: View {
    let reason: WidgetEmptyReason
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(spacing: 6) {
            decorativeSymbol("battery.0percent")
                .font(.title)
            message
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetElement(reason.spokenLabel, strings: strings)
    }

    private var message: Text {
        switch reason {
        case .noBattery: Text("This Mac has no internal battery.", bundle: strings)
        case .noInformation: Text("No battery information", bundle: strings)
        }
    }
}
#endif

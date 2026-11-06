#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// Reads the widget's family and hands the views its size: `\.widgetFamily` can only be read, so
/// the views take the size as an input, which a preview can set. Sets the language the entry
/// draws in, BatteryPulse's own from the feed, for everything below.
struct BatteryWidgetRoot: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Self.content(entry, size: WidgetSize(family))
    }

    /// The widget for `entry` in `size`, in the entry's language: its words, locale and numbers.
    /// The previews draw it too.
    static func content(_ entry: BatteryEntry, size: WidgetSize, timeZone: TimeZone = .autoupdatingCurrent)
        -> some View
    {
        BatteryWidgetView(entry: entry, size: size, formatter: entry.language.formatter, timeZone: timeZone)
            .widgetLanguage(entry.language)
    }
}

extension WidgetSize {
    /// The size of a family the widget declares; any other, extra large among them, draws as
    /// small, the smallest place.
    init(_ family: WidgetFamily) {
        switch family {
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
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
///
/// Extra large isn't declared (the look check left it out of 0.7), so its two-panel views went
/// too: they come back with the family. BatteryCore still plans its panels, which a size the
/// widget never receives draws here as large.
struct BatteryWidgetView: View {
    let entry: BatteryEntry
    let size: WidgetSize
    var formatter = BatteryFormatter.widget
    var timeZone = TimeZone.autoupdatingCurrent

    var body: some View {
        let plan = WidgetLayoutPlan.make(
            size: size, configuration: entry.configuration, snapshot: entry.snapshot, entry: entry.moment,
            formatter: formatter, timeZone: timeZone, feed: entry.feed)
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
                case .large, .extraLarge, .extraLargePortrait:
                    WidgetLargeLayout(layout: layout)
                }
            case .empty(let reason):
                WidgetEmptyState(reason: reason)
            }
        }
        .widgetURL(plan.route.url)
    }
}

/// Large: the charge block at the top and the details below it, in two columns of tiles, and the
/// History chart in the last row's place, which takes what is left of the height.
struct WidgetLargeLayout: View {
    let layout: BatteryWidgetLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetChargeBlock(layout: layout, size: .large, fills: layout.details.isEmpty && layout.chart == nil)
            if let chart = layout.chart {
                Divider()
                if !layout.details.isEmpty {
                    WidgetTileGrid(details: layout.details, tinted: layout.tinted)
                }
                WidgetChartPlace(content: chart)
                    .frame(minHeight: 40, maxHeight: .infinity)
            } else if !layout.details.isEmpty {
                Spacer(minLength: 0)
                Divider()
                WidgetTileGrid(details: layout.details, tinted: layout.tinted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The message of a widget without a battery to show: one VoiceOver element, the message. A Mac
/// without a battery may still have accessories, so its message points to their widget.
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
            if reason == .noBattery {
                Text("Try the Accessories widget", bundle: strings)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetElement(reason.spokenLabel, strings: strings)
    }

    /// The message; without information, its shorter words where its own don't fit one line, so
    /// the Russian takes one line as the English does.
    @ViewBuilder private var message: some View {
        switch reason {
        case .noBattery:
            Text("This Mac has no internal battery.", bundle: strings)
        case .noInformation:
            ViewThatFits(in: .horizontal) {
                Text("No battery information", bundle: strings)
                Text("No battery data", bundle: strings)
            }
        }
    }
}
#endif

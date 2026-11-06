#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// Reads the widget's family and hands the views its size and the entry's plan, in the language the
/// entry draws in, as the Battery widget's root does.
struct DevicesWidgetRoot: View {
    let entry: DevicesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Self.content(entry, size: WidgetSize(family))
    }

    /// The widget for `entry` in `size`, in the entry's language, as the Battery widget's root
    /// draws its own. The previews draw it too. The view holds only the plan, so it stays small.
    static func content(_ entry: DevicesEntry, size: WidgetSize, timeZone: TimeZone = .autoupdatingCurrent)
        -> some View
    {
        DevicesWidgetView(
            plan: DevicesWidgetPlan.make(
                size: size, configuration: entry.configuration, feed: entry.feed?.feed, entry: entry.moment,
                formatter: entry.language.formatter, timeZone: timeZone),
            size: size
        )
        .widgetLanguage(entry.language)
    }
}

/// One entry of the iPhone & iPad widget, as ``DevicesWidgetPlan`` laid it out for the size.
///
/// - One device: its charge large, its name, state and read time; medium adds its details beside
///   it and large under it, as the Battery widget lays out its own.
/// - All: a row per device, its name and charge over its state and read time.
///
/// Names may be their owners' own, so they are privacy sensitive; the numbers stay. A feed over
/// two hours old keeps its last readings and says "Open BatteryPulse to update" under them.
struct DevicesWidgetView: View {
    let plan: DevicesWidgetPlan
    let size: WidgetSize

    var body: some View {
        Group {
            switch plan {
            case .devices(let layout):
                VStack(alignment: .leading, spacing: 6) {
                    if layout.showsOne, let row = layout.rows.first {
                        DeviceOneView(row: row, size: size)
                    } else {
                        DeviceListView(rows: layout.rows, roomy: size != .small && size != .medium)
                    }
                    if layout.isOutdated {
                        WidgetOutdatedLine()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .empty(let reason):
                DevicesEmptyState(reason: reason)
            }
        }
        .widgetURL(plan.route.url)
    }
}

/// One device, laid out for the size: the device block alone in small, its details beside it in
/// medium (a row each) and under it in large (tiles in two columns).
struct DeviceOneView: View {
    let row: DeviceWidgetRow
    let size: WidgetSize

    var body: some View {
        let details = row.details.map(WidgetDetail.row)
        if size == .small || size == .medium {
            HStack(spacing: 16) {
                DeviceBlock(row: row, roomy: false)
                if !details.isEmpty {
                    Divider()
                    WidgetDetailList(details: details, tinted: true)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                DeviceBlock(row: row, roomy: true)
                if !details.isEmpty {
                    Divider()
                    WidgetTileGrid(details: details, tinted: true)
                }
            }
        }
    }
}

/// A device's symbol, its charge large, its name, its state and when it was read: one VoiceOver
/// element, "name, charge, state, Updated 14:05".
struct DeviceBlock: View {
    let row: DeviceWidgetRow
    /// Large has room for a bigger number.
    let roomy: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            decorativeSymbol(row.symbolName)
                .font(roomy ? .title : .title2)
            Spacer(minLength: 0)
            DeviceChargeLabel(row: row, boltFont: .caption)
                .font(.system(size: roomy ? 40 : 34, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
            DeviceNameText(name: row.name)
                .font(.caption)
            VStack(alignment: .leading, spacing: 4) {
                row.stateText(strings)
                row.updatedText(strings)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetElement(row.spokenLabel, strings: strings)
    }
}

/// All's devices: a row each, its symbol, its name and charge over its state and read time. Each
/// row is one VoiceOver element.
struct DeviceListView: View {
    let rows: [DeviceWidgetRow]
    /// Large spaces its rows out and draws them a size larger.
    let roomy: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: roomy ? 12 : 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    decorativeSymbol(row.symbolName)
                        .font(roomy ? .title3 : .body)
                        .foregroundStyle(.secondary)
                        .frame(width: roomy ? 24 : 20)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 8) {
                            DeviceNameText(name: row.name)
                            Spacer(minLength: 8)
                            DeviceChargeLabel(row: row, boltFont: .caption2)
                                .fixedSize()
                        }
                        .font(roomy ? .body : .callout)
                        HStack(spacing: 8) {
                            row.stateText(strings)
                            Spacer(minLength: 8)
                            row.updatedText(strings)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
                .widgetElement(row.spokenLabel, strings: strings)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A device's charge, with the symbol of a low one before it and a bolt after it while it charges,
/// in the font around it; the bolt in `boltFont`.
struct DeviceChargeLabel: View {
    let row: DeviceWidgetRow
    let boltFont: Font
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if let cue = row.cue {
                WidgetCueSymbol(cue: cue, tinted: true)
            }
            Text(verbatim: row.charge)
                .monospacedDigit()
                .foregroundStyle(row.chargeStyle(renderingMode))
            if row.isCharging {
                decorativeSymbol("bolt.fill")
                    .font(boltFont)
            }
        }
    }
}

/// A device's name, which may be its owner's own ("Anna's iPhone"): one line, cut at its end, and
/// privacy sensitive. The only view that shows a device's name.
struct DeviceNameText: View {
    let name: DeviceWidgetName
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        text
            .lineLimit(1)
            .truncationMode(.tail)
            .privacySensitive()
    }

    private var text: Text {
        switch name {
        case .named(let name): Text(verbatim: name)
        case .unknown: Text("Unknown Device", bundle: strings)
        }
    }
}

/// The message of an iPhone & iPad widget without a device to show: one VoiceOver element, the
/// message.
struct DevicesEmptyState: View {
    let reason: DevicesWidgetEmptyReason
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(spacing: 6) {
            decorativeSymbol("ipad.and.iphone")
                .font(.title)
            widgetText(reason.message, strings)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetElement(reason.spokenLabel, strings: strings)
    }
}

extension DeviceWidgetRow {
    /// The charge's colour, as the app's: orange or red when low in full colour, and the primary
    /// style otherwise and in the other rendering modes. The cue beside a low charge says the same
    /// without colour.
    func chargeStyle(_ renderingMode: WidgetRenderingMode) -> AnyShapeStyle {
        renderingMode == .fullColor && tier != .normal ? AnyShapeStyle(tier.color) : AnyShapeStyle(.primary)
    }

    /// The state's words.
    func stateText(_ strings: Bundle?) -> Text {
        widgetText(state.title, strings)
    }

    /// "Updated 14:05", "Updated Oct 30"; nothing without a read time.
    func updatedText(_ strings: Bundle?) -> Text? {
        updated.map { Text("Updated \($0)", bundle: strings) }
    }
}

// The iPhone & iPad widget's own words, as resources so the previews' tests can compare their keys
// with the ones VoiceOver's labels use (BatteryCore's `DevicesWidgetPlan`).

extension DevicesWidgetEmptyReason {
    var message: LocalizedStringResource {
        switch self {
        case .noFeed: "Open BatteryPulse to update"
        case .readsOff: "Turn on Read iPhone and iPad batteries in BatteryPulse"
        case .noDevices: "Connect an iPhone or iPad with a cable"
        case .forgotten: "This device was forgotten"
        }
    }
}
#endif

#if os(macOS)
import AppKit
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// Reads the widget's family and hands the views its size, as the Battery widget's root does.
struct AccessoriesWidgetRoot: View {
    let entry: AccessoriesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        AccessoriesWidgetView(entry: entry, size: WidgetSize(family))
    }
}

/// One entry of the Accessories widget, as ``AccessoriesWidgetPlan`` lays it out for the size;
/// every state opens the Accessories page.
///
/// - Small, and Lowest only: the lowest accessory, its charge large.
/// - Medium and large: a row per accessory, lowest first, with each part's charge.
///
/// Names are the accessories' own, so they are marked privacy sensitive in case macOS ever redacts
/// a widget; the charges stay.
struct AccessoriesWidgetView: View {
    let entry: AccessoriesEntry
    let size: WidgetSize
    var formatter = BatteryFormatter.widget
    var timeZone = TimeZone.autoupdatingCurrent

    var body: some View {
        let plan = AccessoriesWidgetPlan.make(
            size: size, configuration: entry.configuration, accessories: entry.accessories, readAt: entry.readAt,
            entry: entry.moment, formatter: formatter, timeZone: timeZone)
        Group {
            switch plan {
            case .accessories(let layout):
                VStack(alignment: .leading, spacing: 6) {
                    if layout.showsLowest, let row = layout.rows.first {
                        AccessoryLowestView(row: row, roomy: size != .small && size != .medium)
                    } else {
                        AccessoryListView(rows: layout.rows, roomy: size != .small && size != .medium)
                    }
                    if let updated = layout.updated {
                        AccessoriesUpdatedLine(clock: updated)
                    }
                }
            case .empty(let reason):
                AccessoriesEmptyState(reason: reason)
            }
        }
        .widgetURL(plan.route.url)
    }
}

/// The lowest accessory: its symbol, its charge large, its name, and its parts or its state. One
/// VoiceOver element, "name, charge".
struct AccessoryLowestView: View {
    let row: AccessoryWidgetRow
    /// Large has room for a bigger number.
    let roomy: Bool
    @Environment(\.widgetStrings) private var strings
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetAccessorySymbol(name: row.symbolName)
                .font(roomy ? .title : .title2)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: row.level.text)
                    .font(.system(size: roomy ? 40 : 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(row.level.style(renderingMode))
                if row.level.isCharging {
                    decorativeSymbol("bolt.fill")
                        .font(.caption)
                }
                if let cue = row.level.cue {
                    WidgetCueSymbol(cue: cue, tinted: true)
                }
            }
            AccessoryNameText(name: row.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            if row.hasParts {
                AccessoryLowestPartsView(parts: row.parts)
                    .font(.caption)
            } else if let status = row.parts.first?.charge.status {
                // The state's words, or its shorter ones where they don't fit at full size.
                ViewThatFits(in: .horizontal) {
                    status.text(strings)
                    if let short = status.shortTitle {
                        widgetText(short, strings)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetElement(row.spokenLabel, strings: strings)
    }
}

/// The accessories, lowest first: a row each with its symbol, its name and each part's charge, as
/// the menu bar panel lists them. Each row is one VoiceOver element.
struct AccessoryListView: View {
    let rows: [AccessoryWidgetRow]
    /// Large spaces its rows out and draws them a size larger.
    let roomy: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: roomy ? 14 : 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    WidgetAccessorySymbol(name: row.symbolName)
                        .foregroundStyle(.secondary)
                        .frame(width: roomy ? 24 : 20)
                    AccessoryNameText(name: row.name)
                        .layoutPriority(0)
                    Spacer(minLength: 8)
                    AccessoryPartsView(parts: row.parts, hasParts: row.hasParts)
                        .layoutPriority(1)
                }
                .widgetElement(row.spokenLabel, strings: strings)
            }
        }
        .font(roomy ? .body : .callout)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// An accessory's or a part's symbol, or the generic accessory symbol where this macOS lacks it, as
/// the app draws them. In the accented rendering mode it stays in the default group, like the
/// words beside it: `.desaturated` maps an image's luminance to its alpha, which suits a picture
/// but leaves a dark symbol all but invisible (CI's accented pictures in light).
struct WidgetAccessorySymbol: View {
    let name: String

    var body: some View {
        let available = NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        decorativeSymbol(available ? name : AccessoryKind.fallbackSymbolName)
    }
}

/// An accessory's name, which may be a person's own ("Anna's AirPods"): one line, cut at its end,
/// and privacy sensitive.
struct AccessoryNameText: View {
    let name: AccessoryWidgetName
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        text
            .lineLimit(1)
            .truncationMode(.tail)
            .privacySensitive()
    }

    private var text: Text {
        switch name {
        case .reported(let name): Text(verbatim: name)
        case .kind(let kind): widgetText(kind.title, strings)
        }
    }
}

/// Each part's charge, side by side: with parts, each after its symbol (left, right, case), and a
/// bolt after a part that charges. The numbers are never cut.
struct AccessoryPartsView: View {
    let parts: [AccessoryWidgetPart]
    let hasParts: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                HStack(spacing: 2) {
                    if hasParts, let symbol = part.role.symbolName {
                        WidgetAccessorySymbol(name: symbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let cue = part.charge.cue {
                        WidgetCueSymbol(cue: cue, tinted: true)
                    }
                    Text(verbatim: part.charge.text)
                        .monospacedDigit()
                        .foregroundStyle(part.charge.style(renderingMode))
                    if part.charge.isCharging {
                        decorativeSymbol("bolt.fill")
                            .font(.caption2)
                    }
                }
            }
        }
        .fixedSize()
    }
}

/// The lowest accessory's parts: on one line where they fit, else the case on a line of its own
/// under the buds, so a charge is never cut. Small fits even three parts at 100% on one line in
/// English and Russian; before percentages lost the space before the sign, Russian's ran about 15
/// points past the margin, and a wider number format still could.
struct AccessoryLowestPartsView: View {
    let parts: [AccessoryWidgetPart]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            AccessoryPartsView(parts: parts, hasParts: true)
            VStack(alignment: .leading, spacing: 2) {
                AccessoryPartsView(parts: parts.filter { $0.role != .case }, hasParts: true)
                AccessoryPartsView(parts: parts.filter { $0.role == .case }, hasParts: true)
            }
        }
    }
}

extension AccessoryWidgetCharge {
    /// The charge's colour, as the app's: orange or red when low in full colour, dimmed when it is
    /// only the last charge reported, and the primary style otherwise and in the other rendering
    /// modes. The cue beside a low charge says the same without colour.
    func style(_ renderingMode: WidgetRenderingMode) -> AnyShapeStyle {
        if isOffline { return AnyShapeStyle(.secondary) }
        return renderingMode == .fullColor && tier != .normal ? AnyShapeStyle(tier.color) : AnyShapeStyle(.primary)
    }
}

/// "Updated 14:05", once the reading is old. Its own VoiceOver element.
struct AccessoriesUpdatedLine: View {
    let clock: String
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        Text("Updated \(clock)", bundle: strings)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// The message of an Accessories widget with nothing to list: one VoiceOver element, the message.
struct AccessoriesEmptyState: View {
    let reason: AccessoriesWidgetEmptyReason
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(spacing: 6) {
            decorativeSymbol(symbolName)
                .font(.title)
            message
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetElement(reason.spokenLabel, strings: strings)
    }

    private var symbolName: String {
        switch reason {
        case .noAccessories: AccessoryKind.fallbackSymbolName
        case .allFullyCharged: "battery.100percent"
        }
    }

    private var message: Text {
        switch reason {
        case .noAccessories: Text("No accessories with batteries connected", bundle: strings)
        case .allFullyCharged: Text("All accessories are fully charged", bundle: strings)
        }
    }
}

// The Accessories widget's words, as resources so the previews' tests can compare their keys with
// the ones VoiceOver's labels use (BatteryCore's `AccessoriesWidgetPlan`).

extension AccessoryKind {
    /// The app's name for the kind, an accessory's name when it reports none.
    var title: LocalizedStringResource {
        switch self {
        case .keyboard: "Keyboard"
        case .mouse: "Mouse"
        case .trackpad: "Trackpad"
        case .headphones: "Headphones"
        case .speaker: "Speaker"
        case .gameController: "Game Controller"
        case .hearingAid: "Hearing Aid"
        case .other: "Accessory"
        }
    }
}

extension AccessoryWidgetStatus {
    /// The app's words for the state beside an accessory's charge.
    var title: LocalizedStringResource {
        switch self {
        case .charging: "Charging"
        case .lastKnownCharge: "Last known charge"
        case .connectedToPower: "Connected to power"
        }
    }

    func text(_ strings: Bundle?) -> Text {
        widgetText(title, strings)
    }

    /// The shorter words where the state doesn't fit small's line (BatteryCore's `shortKey`).
    var shortTitle: LocalizedStringResource? {
        switch self {
        case .lastKnownCharge: "Last charge"
        case .charging, .connectedToPower: nil
        }
    }
}
#endif

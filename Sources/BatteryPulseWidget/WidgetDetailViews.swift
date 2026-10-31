#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// A line under the main value: one line that shrinks a little before it is cut off, and a
/// VoiceOver element of its own, except the state, which the charge's element reads. A value is
/// never cut: small's detail cuts its label instead, and small's attention row takes a second line
/// for its words rather than lose them (Service Recommended, in Russian).
struct WidgetLineView: View {
    let line: WidgetLine
    let tinted: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        let text =
            content
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.8)
        if let label = line.spokenLabel {
            text.widgetElement(label, strings: strings)
        } else {
            text.accessibilityHidden(true)
        }
    }

    private var lineLimit: Int {
        if case .attention = line { 2 } else { 1 }
    }

    @ViewBuilder private var content: some View {
        switch line {
        case .state(let word):
            widgetText(word.title, strings)
        case .time(let time):
            WidgetTimeLabel(time: time)
        case .updated(let clock):
            Text("Updated \(clock)", bundle: strings)
        case .detail(let row):
            // Small's one detail, in the time line's place: a label and its value, or a time's
            // phrase alone.
            if case .time(let time) = row.value {
                WidgetTimeLabel(time: time)
            } else {
                HStack(spacing: 4) {
                    widgetText(row.field.label, strings)
                    WidgetValueLabel(row: row, tinted: tinted)
                        .fixedSize()
                }
            }
        case .attention(let attention):
            WidgetAttentionLabel(attention: attention, tinted: tinted)
        }
    }
}

/// Medium's details beside the charge block: a label and its value per row, as in 0.6.x, with
/// the attention row last. Each row is one VoiceOver element, "label, value": the value's cell
/// carries the row's label, since a grid row can't take modifiers without leaving the grid.
struct WidgetDetailList: View {
    let details: [WidgetDetail]
    let tinted: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                switch detail {
                case .row(let row):
                    if case .time(let time) = row.value {
                        // A time row is its phrase alone.
                        GridRow {
                            WidgetTimeLabel(time: time)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .widgetElement(row.spokenLabel, strings: strings)
                                .gridCellColumns(2)
                        }
                    } else {
                        GridRow {
                            // Russian labels are longer: they shrink a little before they would be
                            // cut off.
                            widgetText(row.field.label, strings)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .accessibilityHidden(true)
                            WidgetValueLabel(row: row, tinted: tinted)
                                .monospacedDigit()
                                .fixedSize()
                                .widgetElement(row.spokenLabel, strings: strings)
                                .gridColumnAlignment(.trailing)
                        }
                    }
                case .attention(let attention):
                    GridRow {
                        WidgetAttentionLabel(attention: attention, tinted: tinted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .widgetElement(attention.spokenLabel, strings: strings)
                            .gridCellColumns(2)
                    }
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Large's and extra large's details: tiles in two columns, each a label over its value, filled
/// row by row in the plan's order, which is the order VoiceOver reads them in.
struct WidgetTileGrid: View {
    let details: [WidgetDetail]
    let tinted: Bool

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(Array(stride(from: 0, to: details.count, by: 2)), id: \.self) { start in
                GridRow {
                    WidgetTile(detail: details[start], tinted: tinted)
                    if start + 1 < details.count {
                        WidgetTile(detail: details[start + 1], tinted: tinted)
                    } else {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
    }
}

/// One detail as a tile: its label, then its value a size larger; a time's phrase alone; or the
/// attention row's subject over its symbol and words. One VoiceOver element.
struct WidgetTile: View {
    let detail: WidgetDetail
    let tinted: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .widgetElement(detail.spokenLabel, strings: strings)
    }

    @ViewBuilder private var content: some View {
        switch detail {
        case .row(let row):
            if case .time(let time) = row.value {
                WidgetTimeLabel(time: time)
                    .font(.callout)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                tile(label: widgetText(row.field.label, strings)) {
                    WidgetValueLabel(row: row, tinted: tinted)
                }
            }
        case .attention(.heat(let state)):
            tile(label: Text("Thermal state", bundle: strings)) {
                WidgetAttentionLabel(attention: .heat(state), tinted: tinted)
            }
        case .attention(.condition(let condition)):
            tile(label: widgetText(BatteryWidgetField.condition.label, strings)) {
                WidgetAttentionLabel(attention: .condition(condition), tinted: tinted)
            }
        }
    }

    /// A label over its value. Labels shrink a little before they would be cut off; a value takes
    /// a second line rather than be cut (a condition's words in Russian). The tile keeps its own
    /// height: a symbol taller than the text (heat's thermometer) made the grid squeeze its label.
    private func tile<Value: View>(label: Text, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            value()
                .font(.title3.weight(.medium))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Extra large's Power panel opens with its first detail drawn large, as the charge opens the
/// Battery panel: its label over the number, one VoiceOver element like any row.
struct WidgetHeroDetail: View {
    let row: WidgetRow
    let text: String
    let tinted: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            widgetText(row.field.label, strings)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: text)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let cue = row.cue {
                    WidgetCueSymbol(cue: cue, tinted: tinted)
                }
            }
        }
        .widgetElement(row.spokenLabel, strings: strings)
    }

    /// The first of `details` drawn large, when it is a number, and the rest.
    static func split(_ details: [WidgetDetail]) -> (hero: (row: WidgetRow, text: String)?, rest: [WidgetDetail]) {
        guard case .row(let row)? = details.first, case .text(let text) = row.value else { return (nil, details) }
        return ((row, text), Array(details.dropFirst()))
    }
}

/// A detail's value, with the symbol of a tier that isn't normal before it.
struct WidgetValueLabel: View {
    let row: WidgetRow
    let tinted: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        HStack(spacing: 2) {
            if let cue = row.cue {
                WidgetCueSymbol(cue: cue, tinted: tinted)
            }
            switch row.value {
            case .text(let text): Text(verbatim: text)
            case .state(let word): widgetText(word.title, strings)
            case .condition(let condition): condition.text(strings)
            case .onOff(true): Text("On", bundle: strings)
            case .onOff(false): Text("Off", bundle: strings)
            case .time(let time): WidgetTimeLabel(time: time)
            case .reached: Text("Reached", bundle: strings)
            }
        }
    }
}

/// The time to full or empty: the end's clock time in its phrase, or the time left, which the
/// system counts down by the minute without a reload.
struct WidgetTimeLabel: View {
    let time: WidgetTimeText
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        switch time.form {
        case .clock(let clock, tomorrow: false):
            switch time.direction {
            case .full: Text("Full at \(clock)", bundle: strings)
            case .empty: Text("Lasts until about \(clock)", bundle: strings)
            }
        case .clock(let clock, tomorrow: true):
            switch time.direction {
            case .full: Text("Full at \(clock) tomorrow", bundle: strings)
            case .empty: Text("Lasts until \(clock) tomorrow", bundle: strings)
            }
        case .timeLeft:
            Text(.currentDate, format: .offset(to: time.end, allowedFields: [.hour, .minute], sign: .never))
        }
    }
}

/// A condition other than Normal, or heat: a symbol and the app's words for it.
struct WidgetAttentionLabel: View {
    let attention: WidgetAttention
    let tinted: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        HStack(spacing: 4) {
            decorativeSymbol(attention.symbolName)
                .foregroundStyle(renderingMode == .fullColor && tinted ? attention.tier.color : .secondary)
            switch attention {
            case .heat(let state): widgetText(state.title, strings)
            case .condition(let condition): condition.text(strings)
            }
        }
    }
}

/// The symbol beside a value whose tier isn't normal, so colour is never the only signal; its
/// meaning is in the words beside it and in VoiceOver's label.
struct WidgetCueSymbol: View {
    let cue: WidgetCue
    let tinted: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        decorativeSymbol(cue.symbolName)
            .font(.caption)
            .foregroundStyle(renderingMode == .fullColor && tinted ? tier.color : .secondary)
    }

    private var tier: BatteryPresentation.LevelTier {
        switch cue {
        case .low: .low
        case .critical: .critical
        }
    }
}
#endif

#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// A line under the main value: one line at full size, and a VoiceOver element of its own,
/// except the state, which the charge's element reads. Where a detail's label or the attention
/// row's words don't fit, the line takes the field's or the condition's shorter words (the same
/// in every language, so a Russian line lays out as the English one does); only a line longer
/// still shrinks a little. A value is never cut.
struct WidgetLineView: View {
    let line: WidgetLine
    let tinted: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        let text =
            content
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        if let label = line.spokenLabel {
            text.widgetElement(label, strings: strings)
        } else {
            text.accessibilityHidden(true)
        }
    }

    @ViewBuilder private var content: some View {
        switch line {
        case .state(let word):
            widgetText(word.title, strings)
        case .time(let time):
            WidgetTimeLabel(time: time, oneLine: true)
        case .updated(let clock):
            Text("Updated \(clock)", bundle: strings)
        case .detail(let row):
            // Small's one detail, in the time line's place: a label and its value, or a time's
            // phrase alone.
            if case .time(let time) = row.value {
                WidgetTimeLabel(time: time, oneLine: true)
            } else {
                WidgetDetailRow(row: row, tinted: tinted, spreads: false)
            }
        case .attention(let attention):
            WidgetAttentionLabel(attention: attention, tinted: tinted, oneLine: true)
        }
    }
}

/// Medium's details beside the charge block: a row per detail, its label at the leading edge and
/// its value at the trailing one, with the attention row last. The rows span the whole column, so
/// the values end where the column does in every language (0.6.x's grid ended where its widest
/// row did, further right in Russian). Each row is one VoiceOver element, "label, value".
struct WidgetDetailList: View {
    let details: [WidgetDetail]
    let tinted: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                switch detail {
                case .row(let row):
                    if case .time(let time) = row.value {
                        // A time row is its phrase alone.
                        WidgetTimeLabel(time: time, oneLine: true)
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.8)
                            .widgetElement(row.spokenLabel, strings: strings)
                    } else {
                        WidgetDetailRow(row: row, tinted: tinted, spreads: true)
                            .widgetElement(row.spokenLabel, strings: strings)
                    }
                case .attention(let attention):
                    WidgetAttentionLabel(attention: attention, tinted: tinted, oneLine: true)
                        .minimumScaleFactor(0.8)
                        .widgetElement(attention.spokenLabel, strings: strings)
                }
            }
        }
        .font(.caption)
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// A detail's label and its value on one line at full size: the field's label, or its shorter one
/// where the label doesn't fit beside the value (the same in every language, so the two lay out
/// alike), or a state or condition alone, which says what it is. Only when nothing fits does the
/// label shrink a little, then truncate; the value never does. Medium's row `spreads` across its
/// column, with the value at the trailing edge; small's line keeps the value beside its label.
struct WidgetDetailRow: View {
    let row: WidgetRow
    let tinted: Bool
    let spreads: Bool
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line(widgetText(row.field.label, strings))
            if let short = row.field.shortLabel {
                line(widgetText(short, strings))
            }
            if row.standsAlone {
                value
            }
            line(widgetText(row.field.shortLabel ?? row.field.label, strings))
                .minimumScaleFactor(0.8)
        }
    }

    private func line(_ label: Text) -> some View {
        HStack(spacing: spreads ? 0 : 4) {
            label
                .foregroundStyle(.secondary)
            if spreads {
                Spacer(minLength: 8)
            }
            value
        }
    }

    /// Medium's values line up their digits in a column, as 0.6.x's did.
    private var value: some View {
        WidgetValueLabel(row: row, tinted: tinted)
            .font(spreads ? Font.caption.monospacedDigit() : .caption)
            .fixedSize()
    }
}

extension WidgetRow {
    /// A value whose words say what it is, so it can stand without its label: a state, a condition.
    fileprivate var standsAlone: Bool {
        switch value {
        case .state, .condition: true
        case .text, .onOff, .time, .reached: false
        }
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
/// system counts down by the minute without a reload. On `oneLine`, a line under the main value
/// and medium's time row, a phrase too long for its place takes its shorter form (BatteryCore's
/// `shortKey`) in every language; a tile has two lines for it.
struct WidgetTimeLabel: View {
    let time: WidgetTimeText
    var oneLine = false
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
            case .empty:
                if oneLine {
                    ViewThatFits(in: .horizontal) {
                        Text("Lasts until \(clock) tomorrow", bundle: strings)
                        Text("Until \(clock) tomorrow", bundle: strings)
                    }
                } else {
                    Text("Lasts until \(clock) tomorrow", bundle: strings)
                }
            }
        case .timeLeft:
            Text(.currentDate, format: .offset(to: time.end, allowedFields: [.hour, .minute], sign: .never))
        }
    }
}

/// A condition other than Normal, or heat: a symbol and the app's words for it. On `oneLine`,
/// small's line and medium's row, the condition's shorter words take the place of its own when
/// those don't fit at full size, as a detail's short label does; a tile has two lines for them.
struct WidgetAttentionLabel: View {
    let attention: WidgetAttention
    let tinted: Bool
    var oneLine = false
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        if oneLine, case .condition(let condition) = attention, let short = condition.shortTitle {
            ViewThatFits(in: .horizontal) {
                label(condition.text(strings))
                label(widgetText(short, strings))
            }
        } else {
            switch attention {
            case .heat(let state): label(widgetText(state.title, strings))
            case .condition(let condition): label(condition.text(strings))
            }
        }
    }

    private func label(_ words: Text) -> some View {
        HStack(spacing: 4) {
            decorativeSymbol(attention.symbolName)
                .foregroundStyle(renderingMode == .fullColor && tinted ? attention.tier.color : .secondary)
            words
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

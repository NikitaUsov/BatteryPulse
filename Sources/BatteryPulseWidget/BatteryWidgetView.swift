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

/// One entry of the Battery widget, as ``WidgetLayoutPlan`` lays it out for the size: the charge
/// block (the level symbol, the main value and the lines under it) and, beside it, the details.
/// One `widgetURL` opens the page about the main value, or the one that fixes an empty state.
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
            case .battery(let layout) where size == .small || layout.details.isEmpty:
                WidgetChargeBlock(layout: layout)
            case .battery(let layout):
                HStack(spacing: 16) {
                    WidgetChargeBlock(layout: layout)
                    Divider()
                    WidgetDetailList(details: layout.details, tinted: layout.tinted)
                }
            case .empty(let reason):
                WidgetEmptyState(reason: reason)
            }
        }
        .widgetURL(plan.route.url)
    }
}

/// The level symbol, the main value and the lines under it, as in 0.6.x.
struct WidgetChargeBlock: View {
    let layout: BatteryWidgetLayout
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // WidgetKit animates from one timeline entry to the next by itself; these say how the
        // symbol and the number change. Nothing runs between entries.
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: layout.level.symbolName)
                    .font(.title2)
                    // The level's colour only in full colour; in the accented and vibrant modes the
                    // system colours the symbol itself (it is in the accent group).
                    .foregroundStyle(renderingMode == .fullColor && layout.tinted ? layout.level.tier.color : .primary)
                    .widgetAccentable()
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                if let cue = layout.level.cue {
                    WidgetCueSymbol(cue: cue, tinted: layout.tinted)
                }
            }
            Spacer(minLength: 0)
            mainValue
            ForEach(Array(layout.lines.enumerated()), id: \.offset) { _, line in
                WidgetLineView(line: line, tinted: layout.tinted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var mainValue: some View {
        let number = Text(verbatim: layout.main.text)
            .font(.system(size: 34, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .contentTransition(reduceMotion ? .opacity : .numericText(value: layout.main.number))
        if let cue = layout.main.cue {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                number
                WidgetCueSymbol(cue: cue, tinted: layout.tinted)
            }
        } else {
            number
        }
    }
}

/// A line under the main value: one line that shrinks a little before it is cut off.
struct WidgetLineView: View {
    let line: WidgetLine
    let tinted: Bool

    var body: some View {
        content
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ViewBuilder private var content: some View {
        switch line {
        case .state(let word):
            Text(word.title)
        case .time(let time):
            WidgetTimeLabel(time: time)
        case .updated(let clock):
            Text("Updated \(clock)")
        case .detail(let row):
            // Small's one detail, in the time line's place.
            HStack(spacing: 4) {
                Text(row.field.label)
                WidgetValueLabel(row: row, tinted: tinted)
            }
        case .attention(let attention):
            WidgetAttentionLabel(attention: attention, tinted: tinted)
        }
    }
}

/// The details beside the charge block: a label and its value per row, as in 0.6.x, with the
/// attention row last.
struct WidgetDetailList: View {
    let details: [WidgetDetail]
    let tinted: Bool

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
                                .gridCellColumns(2)
                        }
                    } else {
                        GridRow {
                            // Russian labels are longer: they shrink a little before they would be
                            // cut off.
                            Text(row.field.label)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            WidgetValueLabel(row: row, tinted: tinted)
                                .monospacedDigit()
                                .fixedSize()
                                .gridColumnAlignment(.trailing)
                        }
                    }
                case .attention(let attention):
                    GridRow {
                        WidgetAttentionLabel(attention: attention, tinted: tinted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .gridCellColumns(2)
                    }
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// A detail's value, with the symbol of a tier that isn't normal before it.
struct WidgetValueLabel: View {
    let row: WidgetRow
    let tinted: Bool

    var body: some View {
        HStack(spacing: 2) {
            if let cue = row.cue {
                WidgetCueSymbol(cue: cue, tinted: tinted)
            }
            switch row.value {
            case .text(let text): Text(verbatim: text)
            case .state(let word): Text(word.title)
            case .condition(let condition): condition.text
            case .onOff(true): Text("On")
            case .onOff(false): Text("Off")
            case .time(let time): WidgetTimeLabel(time: time)
            }
        }
    }
}

/// The time to full or empty: the end's clock time in its phrase, or the time left, which the
/// system counts down by the minute without a reload.
struct WidgetTimeLabel: View {
    let time: WidgetTimeText

    var body: some View {
        switch time.form {
        case .clock(let clock, tomorrow: false):
            switch time.direction {
            case .full: Text("Full at \(clock)")
            case .empty: Text("Lasts until about \(clock)")
            }
        case .clock(let clock, tomorrow: true):
            switch time.direction {
            case .full: Text("Full at \(clock) tomorrow")
            case .empty: Text("Lasts until \(clock) tomorrow")
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

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: attention.symbolName)
                .foregroundStyle(renderingMode == .fullColor && tinted ? attention.tier.color : .secondary)
            switch attention {
            case .heat(let state): state.text
            case .condition(let condition): condition.text
            }
        }
    }
}

/// The symbol beside a value whose tier isn't normal, so colour is never the only signal.
struct WidgetCueSymbol: View {
    let cue: WidgetCue
    let tinted: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Image(systemName: cue.symbolName)
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

/// The message of a widget without a battery to show.
struct WidgetEmptyState: View {
    let reason: WidgetEmptyReason

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "battery.0percent")
                .font(.title)
            message
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var message: Text {
        switch reason {
        case .noBattery: Text("This Mac has no internal battery.")
        case .noInformation: Text("No battery information")
        }
    }
}

extension BatteryPresentation.LevelTier {
    /// The level colours of 0.6.x.
    var color: Color {
        switch self {
        case .normal: .green
        case .low: .orange
        case .critical: .red
        }
    }
}

extension WidgetStateWord {
    var title: LocalizedStringKey {
        switch self {
        case .charging: "Charging"
        case .onBattery: "On battery"
        case .fullyCharged: "Fully charged"
        case .chargingOnHold: "Charging on hold"
        case .notCharging: "Not charging"
        case .unknown: "Unknown"
        }
    }
}

extension WidgetCondition {
    /// The app's words for the condition; one it has no words for, as macOS reports it.
    var text: Text {
        switch self {
        case .normal: Text("Normal")
        case .fair: Text("Fair")
        case .poor: Text("Poor")
        case .checkBattery: Text("Check Battery")
        case .serviceRecommended: Text("Service Recommended")
        case .other(let raw): Text(verbatim: raw)
        }
    }
}

extension ThermalState {
    /// The app's words for the thermal state ("High", "Critical").
    var text: Text {
        switch self {
        case .nominal: Text("Normal")
        case .fair: Text("Elevated")
        case .serious: Text("High")
        case .critical: Text("Critical")
        }
    }
}
#endif

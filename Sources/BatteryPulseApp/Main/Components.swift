#if os(macOS)
import BatteryCore
import SwiftUI

// Content-layer building blocks. Per Apple's Liquid Glass guidance, glass belongs to the
// navigation and control layer (sidebar, toolbar, controls), which SwiftUI provides; content
// uses standard fills.

/// A rounded section of the Overview page.
struct Card<Content: View>: View {
    private let title: LocalizedStringKey?
    private let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

/// A ring-shaped gauge (the built-in circular style is watchOS-only).
struct RingGaugeStyle: GaugeStyle {
    var tint: Color
    var diameter: CGFloat = 112
    var lineWidth: CGFloat = 11

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, configuration.value)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                configuration.currentValueLabel
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                configuration.label
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(lineWidth)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Gauge tile used on the Overview: a ring with a caption underneath.
struct GaugeTile: View {
    let title: LocalizedStringKey
    let fraction: Double
    let value: String
    let caption: String?
    let tint: Color

    var body: some View {
        Card {
            VStack(spacing: 10) {
                Gauge(value: fraction) {
                    Text(title)
                } currentValueLabel: {
                    Text(value)
                }
                .gaugeStyle(RingGaugeStyle(tint: tint))
                if let caption {
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// A battery drawn to the exact level, with a bolt while charging.
struct BatteryGlyph: View {
    let level: Double
    let isCharging: Bool
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let terminalWidth = height * 0.12
            let bodyWidth = geometry.size.width - terminalWidth - height * 0.04
            let inset = height * 0.1
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.24, style: .continuous)
                    .strokeBorder(.secondary, lineWidth: max(2, height * 0.06))
                    .frame(width: bodyWidth)
                RoundedRectangle(cornerRadius: height * 0.15, style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: max(0, (bodyWidth - inset * 2) * min(1, max(0, level))), height: height - inset * 2)
                    .padding(.leading, inset)
                RoundedRectangle(cornerRadius: terminalWidth / 2, style: .continuous)
                    .fill(.secondary)
                    .frame(width: terminalWidth, height: height * 0.36)
                    .offset(x: bodyWidth + height * 0.04)
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.5, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2)
                        .frame(width: bodyWidth)
                }
            }
        }
        .aspectRatio(2.2, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Horizontal capacity bars in the spirit of coconutBattery: remaining, full and design mAh on
/// one scale.
struct CapacityBars: View {
    let snapshot: BatterySnapshot
    let formatter: BatteryFormatter

    private var rows: [(LocalizedStringKey, Int, Color)] {
        var rows: [(LocalizedStringKey, Int, Color)] = []
        if let value = snapshot.currentCapacityMAh { rows.append(("Remaining", value, .green)) }
        if let value = snapshot.fullChargeCapacityMAh { rows.append(("Full charge", value, .teal)) }
        if let value = snapshot.designCapacityMAh { rows.append(("Design", value, .gray)) }
        return rows
    }

    var body: some View {
        let scale = Double(rows.map(\.1).max() ?? 1)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                let (label, value, color) = row
                GridRow {
                    Text(label)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(value), total: scale)
                        .tint(color)
                        .gridColumnAlignment(.leading)
                    Text(formatter.milliampHours(value))
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                }
            }
        }
    }
}

/// Where the power goes: adapter → Mac → battery (or battery → Mac on battery power).
struct PowerFlowView: View {
    let snapshot: BatterySnapshot
    let formatter: BatteryFormatter

    var body: some View {
        let batteryWatts = snapshot.batteryPowerWatts ?? 0
        HStack(alignment: .center, spacing: 0) {
            if snapshot.isExternalPowerConnected == true, let adapter = snapshot.adapter {
                node(
                    symbol: "powerplug.portrait.fill", title: "Adapter",
                    value: adapter.watts.map { formatter.watts(Double($0), fractionDigits: 0) })
                arrow(
                    value: snapshot.systemPowerInWatts.flatMap { $0 > 0 ? formatter.watts($0) : nil },
                    pointsRight: true)
            }
            node(symbol: "laptopcomputer", title: "Mac", value: snapshot.systemLoadWatts.map { formatter.watts($0) })
            arrow(
                value: abs(batteryWatts) >= 0.05 ? formatter.watts(abs(batteryWatts)) : nil,
                pointsRight: batteryWatts >= 0)
            node(
                symbol: BatteryPresentation.symbolName(for: snapshot), title: "Battery",
                value: snapshot.chargePercent.map { formatter.percent($0) })
        }
        .frame(maxWidth: .infinity)
    }

    private func node(symbol: String, title: LocalizedStringKey, value: String?) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }
}

/// A Form row with a label and a monospaced value.
struct ValueRow: View {
    let label: LocalizedStringKey
    let value: String

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
    }
}
#endif

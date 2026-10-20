#if os(macOS)
import BatteryCore
import Charts
import SwiftUI

// What the History charts share: their internal dimension names, the time axis and the hover
// readout.

/// Names of internal chart dimensions (segments, series, rectangle edges). Passed as Strings,
/// not literals, so they aren't localization keys; the user-facing ones (Time, Charge, Watts…)
/// are literals and in the catalog, for VoiceOver and Audio Graphs.
enum ChartKey {
    static let bottom = "Bottom"
    static let top = "Top"
    static let start = "Start"
    static let end = "End"
    static let line = "Line"
    static let segment = "Segment"
    static let series = "Series"
    static let zero = "Zero"
}

/// The rule and readout for the point under the pointer.
struct SelectionOverlay: View {
    let proxy: ChartProxy
    let points: [HistoryPoint]
    @Binding var selection: Date?
    let showsDate: Bool
    let value: (HistoryPoint) -> String?
    @Environment(\.tones) private var tones

    var body: some View {
        GeometryReader { geometry in
            if let selection, let point = HistoryPoint.nearest(in: points, to: selection),
                let text = value(point), let plotFrame = proxy.plotFrame,
                let x = proxy.position(forX: point.time)
            {
                let frame = geometry[plotFrame]
                let position = frame.minX + x
                Rectangle()
                    .fill(.secondary)
                    .frame(width: 1, height: frame.height)
                    .position(x: position, y: frame.midY)
                readout(text, point.time)
                    .fixedSize()
                    // Keep the readout inside the plot near its edges.
                    .position(x: min(max(position, frame.minX + 70), frame.maxX - 70), y: frame.minY + 20)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // Follows the pointer exactly; a period crossfade must not drag the rule along.
        .transaction { $0.animation = nil }
    }

    private func readout(_ value: String, _ time: Date) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(time.formatted(date: showsDate ? .abbreviated : .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        // A card's own surface with the window style's hairline: content, so no material (CLAUDE.md).
        .background(.background.secondary, in: .rect(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(tones.style(.hairline), lineWidth: 0.5))
    }
}

/// The time axis of the period charts.
@MainActor
enum HistoryTimeAxis {
    /// Few ticks on whole hours or days: tick generation is expensive, and labels on odd times
    /// read badly.
    static func marks(for period: HistoryPeriod) -> some AxisContent {
        AxisMarks(values: period == .day ? .stride(by: .hour, count: 6) : .stride(by: .day)) { _ in
            AxisGridLine()
            AxisValueLabel(
                format: period == .day ? .dateTime.hour() : .dateTime.weekday(.abbreviated), centered: period == .week)
        }
    }
}
#endif

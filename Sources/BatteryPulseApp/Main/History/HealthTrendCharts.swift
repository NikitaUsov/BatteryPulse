#if os(macOS)
import BatteryCore
import Charts
import SwiftUI

/// How capacity and cycles change over months, from the daily summaries; whatever the period.
struct HealthTrendCharts: View {
    /// The daily summaries, at noon of their days.
    let days: [HistoryDayPoint]
    @Environment(\.tones) private var tones

    var body: some View {
        if days.count < 2 {
            Text("Capacity and cycles appear here after BatteryPulse has run on two different days.")
                .foregroundStyle(.secondary)
        } else {
            // The tones once per body, not per day.
            let capacityLine = tones.style(.chart(.capacity))
            let cycleLine = tones.style(.chart(.cycles))
            VStack(alignment: .leading, spacing: 12) {
                Text("Capacity compared with design")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Chart(days) { entry in
                    if let capacity = entry.day.capacityToDesignPercent {
                        LineMark(x: .value("Day", entry.date), y: .value("Capacity", capacity))
                            .foregroundStyle(capacityLine)
                        PointMark(x: .value("Day", entry.date), y: .value("Capacity", capacity))
                            .foregroundStyle(capacityLine)
                            .symbolSize(16)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 140)
                Text("Cycle count")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Chart(days) { entry in
                    if let cycles = entry.day.cycleCount {
                        LineMark(x: .value("Day", entry.date), y: .value("Cycles", cycles))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(cycleLine)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 120)
            }
        }
    }
}
#endif

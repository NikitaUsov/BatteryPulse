#if os(macOS)
import BatteryCore
import Charts
import SwiftUI

/// Battery history: charge and power over the last day or week, figures for that period, and
/// how capacity and cycles change over months.
struct HistoryView: View {
    enum Period: String, CaseIterable, Identifiable {
        case day, week
        var id: Self { self }
        var length: TimeInterval { self == .day ? 24 * 60 * 60 : 7 * 24 * 60 * 60 }
        /// Minute samples for a day; ten-minute averages for a week (about 1,000 points).
        var bucket: TimeInterval? { self == .day ? nil : 10 * 60 }
    }

    @State private var period: Period = .day
    @State private var points: [HistoryPoint] = []
    @State private var statistics: HistoryStatistics?
    @State private var days: [HistoryDay] = []
    @State private var hasLoaded = false
    @State private var selectedTime: Date?
    @State private var end = Date()
    private let formatter = BatteryFormatter.app

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Period", selection: $period) {
                    Text("24 Hours").tag(Period.day)
                    Text("7 Days").tag(Period.week)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)

                if hasLoaded, points.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text(
                            "BatteryPulse records the battery about once a minute while it runs. Check back in a few minutes."
                        )
                    )
                    .frame(minHeight: 260)
                } else {
                    Card("Charge") { chargeChart }
                    Card("Power") { powerChart }
                    if let statistics { statisticsRow(statistics) }
                }
                Card("Battery Health") { healthCharts }
            }
            .padding(20)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .task(id: period) {
            // Reload as new samples arrive.
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    // MARK: - Data

    private func load() async {
        end = Date()
        let start = end.addingTimeInterval(-period.length)
        let samples = (try? await AppHistory.store.samples(since: start)) ?? []
        points = HistoryPoint.points(from: samples, bucket: period.bucket)
        statistics = samples.isEmpty ? nil : HistoryStatistics(samples: samples)
        days = (try? await AppHistory.store.dailySummaries()) ?? []
        hasLoaded = true
    }

    private var domain: ClosedRange<Date> {
        end.addingTimeInterval(-period.length)...end
    }

    /// Stretches where the Mac was on its power adapter, shaded behind the charge line.
    private var pluggedInRanges: [ClosedRange<Date>] {
        var ranges: [ClosedRange<Date>] = []
        var start: Date?
        var previous: HistoryPoint?
        for point in points {
            let pluggedIn = point.state == .charging || point.state == .charged || point.state == .notCharging
            let continues = previous.map { $0.segment == point.segment } ?? false
            if pluggedIn, start == nil || !continues {
                if let start, let previous { ranges.append(start...previous.time) }
                start = point.time
            } else if !pluggedIn, let open = start, let previous {
                ranges.append(open...previous.time)
                start = nil
            }
            previous = point
        }
        if let start, let previous { ranges.append(start...previous.time) }
        return ranges
    }

    private var selectedPoint: HistoryPoint? {
        guard let selectedTime else { return nil }
        return points.min {
            abs($0.time.timeIntervalSince(selectedTime)) < abs($1.time.timeIntervalSince(selectedTime))
        }
    }

    // MARK: - Charts

    private var chargeChart: some View {
        Chart {
            ForEach(Array(pluggedInRanges.enumerated()), id: \.offset) { _, range in
                RectangleMark(
                    xStart: .value("Start", range.lowerBound), xEnd: .value("End", range.upperBound),
                    yStart: .value("Bottom", 0), yEnd: .value("Top", 100)
                )
                .foregroundStyle(.green.opacity(0.12))
            }
            ForEach(points) { point in
                if let percent = point.percent {
                    LineMark(
                        x: .value("Time", point.time), y: .value("Charge", percent),
                        series: .value("Segment", point.segment)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.monotone)
                }
            }
            if let point = selectedPoint, let percent = point.percent {
                RuleMark(x: .value("Time", point.time))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        readout(point.time, formatter.percent(percent))
                    }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Double.self) { Text(formatter.percent(percent)) }
                }
            }
        }
        .chartXAxis { timeAxis }
        .chartXSelection(value: $selectedTime)
        .frame(height: 200)
        .overlay(alignment: .topTrailing) {
            Label("On power adapter", systemImage: "square.fill")
                .font(.caption)
                .foregroundStyle(.green.opacity(0.6))
                .labelStyle(.titleAndIcon)
        }
    }

    private var powerChart: some View {
        Chart {
            ForEach(points) { point in
                if let watts = point.batteryWatts {
                    LineMark(
                        x: .value("Time", point.time), y: .value("Watts", watts),
                        series: .value("Series", "battery-\(point.segment)")
                    )
                    .foregroundStyle(by: .value("Line", String(localized: "Battery")))
                }
                if let load = point.systemLoadWatts {
                    LineMark(
                        x: .value("Time", point.time), y: .value("Watts", load),
                        series: .value("Series", "load-\(point.segment)")
                    )
                    .foregroundStyle(by: .value("Line", String(localized: "Mac")))
                }
            }
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(.secondary.opacity(0.5))
            if let point = selectedPoint {
                RuleMark(x: .value("Time", point.time))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        readout(
                            point.time,
                            [point.batteryWatts, point.systemLoadWatts].compactMap { $0 }
                                .map { formatter.watts($0, signed: true) }.joined(separator: " · "))
                    }
            }
        }
        .chartForegroundStyleScale([String(localized: "Battery"): Color.blue, String(localized: "Mac"): Color.orange])
        .chartXScale(domain: domain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let watts = value.as(Double.self) { Text(formatter.watts(watts, fractionDigits: 0)) }
                }
            }
        }
        .chartXAxis { timeAxis }
        .chartXSelection(value: $selectedTime)
        .frame(height: 180)
    }

    private var timeAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: period == .day ? 6 : 7)) { _ in
            AxisGridLine()
            AxisValueLabel(format: period == .day ? .dateTime.hour() : .dateTime.weekday(.abbreviated))
        }
    }

    private func readout(_ time: Date, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(time.formatted(date: period == .day ? .omitted : .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.background.secondary, in: .rect(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Figures

    private func statisticsRow(_ s: HistoryStatistics) -> some View {
        HStack(alignment: .top, spacing: 16) {
            figure(
                "Average drain",
                s.averageDrainPercentPerHour.map {
                    String(localized: "\(formatter.percent($0, fractionDigits: 1)) per hour")
                } ?? "—")
            figure("On battery", formatter.duration(minutes: Int((s.timeOnBattery / 60).rounded())))
            figure(
                "Energy from battery",
                String(localized: "\(formatter.number(s.energyFromBatteryWattHours, fractionDigits: 1)) Wh"))
            figure("Charging sessions", s.chargingSessions.formatted())
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func figure(_ title: LocalizedStringKey, _ value: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var healthCharts: some View {
        let dated = days.compactMap { day in day.date().map { DayPoint(date: $0, day: day) } }
        if dated.count < 2 {
            Text("Capacity and cycles appear here after BatteryPulse has run on two different days.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Capacity compared with design")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Chart(dated) { entry in
                    if let capacity = entry.day.capacityToDesignPercent {
                        LineMark(x: .value("Day", entry.date), y: .value("Capacity", capacity))
                            .foregroundStyle(.green)
                        PointMark(x: .value("Day", entry.date), y: .value("Capacity", capacity))
                            .foregroundStyle(.green)
                            .symbolSize(16)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 140)
                Text("Cycle count")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Chart(dated) { entry in
                    if let cycles = entry.day.cycleCount {
                        LineMark(x: .value("Day", entry.date), y: .value("Cycles", cycles))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(.blue)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 120)
            }
        }
    }
}

/// A daily summary placed at noon of its day.
private struct DayPoint: Identifiable {
    let date: Date
    let day: HistoryDay
    var id: String { day.day }
}
#endif

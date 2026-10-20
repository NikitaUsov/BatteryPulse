#if os(macOS)
import BatteryCore
import BatteryKit
import Charts
import SwiftUI

/// Whose history the History page shows: this Mac's, or a remembered iPhone's or iPad's.
enum HistorySource: Hashable {
    case mac
    case device(DeviceKey)
}

/// Battery history: charge and power over the last day or week, figures for that period, and
/// how capacity and cycles change over months. This Mac's, or a remembered iPhone's or iPad's,
/// picked in the toolbar.
struct HistoryView: View {
    enum Period: String, CaseIterable, Identifiable {
        case day, week
        var id: Self { self }
        var length: TimeInterval { self == .day ? 24 * 60 * 60 : 7 * 24 * 60 * 60 }
        /// Minute samples for a day; ten-minute averages for a week (about 1,000 points).
        var bucket: TimeInterval? { self == .day ? nil : 10 * 60 }
    }

    /// The period picked in the toolbar.
    @State private var period: Period = .day
    /// The period of the data on screen. It follows ``period`` once that period's samples are
    /// loaded, so the charts never draw the old data on the new period's axis.
    @State private var loadedPeriod: Period?
    @State private var points: [HistoryPoint] = []
    @State private var spans: [HistorySpan] = []
    @State private var statistics: HistoryStatistics?
    @State private var days: [HistoryDay] = []
    @State private var hasLoaded = false
    @State private var selectedTime: Date?
    @State private var end = Date()
    /// The Export menu's pick while its file is prepared.
    @State private var exportRequest: HistoryExportRequest?
    /// The source picked in the toolbar; Show in History on a device page sets it too.
    @Binding private var source: HistorySource
    /// The source of the data on screen, like ``loadedPeriod``.
    @State private var loadedSource: HistorySource?
    /// The store the data on screen came from, for exporting what History shows.
    @State private var loadedStore: HistoryStore?
    @Environment(IDeviceMonitor.self) private var devices
    @Environment(DemoController.self) private var demo
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones
    @Environment(\.windowLook) private var look
    private let formatter = BatteryFormatter.app

    init(source: Binding<HistorySource>) {
        _source = source
    }

    /// Restarts the reload loop when the period or the source changes or the window is shown
    /// again.
    private struct ReloadKey: Equatable {
        var period: Period
        var source: HistorySource
        var isVisible: Bool
    }

    /// What the charts show at a time: switching either crossfades them.
    private struct ShownKey: Hashable {
        var period: Period
        var source: HistorySource
    }

    /// Remembered iPhones and iPads, for the source picker.
    private var rememberedDevices: [IDeviceEntry] {
        devices.entries.filter(\.isRemembered)
    }

    /// The picked source while it can be shown: in Demo Mode, and once its device is forgotten,
    /// this Mac.
    private var effectiveSource: HistorySource {
        guard !demo.isActive, case .device(let key) = source, rememberedDevices.contains(where: { $0.id == key })
        else { return .mac }
        return source
    }

    /// "Last seen …" under the title while the shown device isn't connected.
    private var subtitle: Text {
        guard case .device(let key) = shownSource, let entry = devices.entries.first(where: { $0.id == key }),
            entry.connection == nil, let lastSeen = entry.lastSeen
        else { return Text(verbatim: "") }
        return Text("Last seen \(DeviceText.date(lastSeen))")
    }

    var body: some View {
        ScrollView {
            CardGroup {
                VStack(spacing: 16) {
                    // Switching the period crossfades the charts rather than morphing the lines: a day
                    // and a week have different points on different time axes. The ZStack keeps both
                    // periods on top of each other while they fade. The fade is the transition's own,
                    // so under Reduce Motion it stays while the card below snaps to the new height.
                    // Keyed on the period shown, so the first load fills the page without a fade.
                    ZStack(alignment: .top) {
                        periodContent
                            .id(ShownKey(period: shownPeriod, source: shownSource))
                            .transition(motion.fadeTransition)
                    }
                    Card("Battery Health") { healthCharts }
                }
            }
            .padding(20)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            // Only with a device to choose; Demo Mode shows this Mac alone, so screenshots never
            // show a real owner's device name.
            if !rememberedDevices.isEmpty, !demo.isActive {
                ToolbarItem(placement: .navigation) {
                    Picker("Source", selection: $source) {
                        Text("This Mac").tag(HistorySource.mac)
                        ForEach(rememberedDevices) { entry in
                            DeviceText.displayName(entry).tag(HistorySource.device(entry.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            // In the toolbar, like the view switches of the system's own apps, with the system's
            // glass selection. Only while History is shown.
            ToolbarItem(placement: .principal) {
                Picker("Period", selection: $period) {
                    Text("24 Hours").tag(Period.day)
                    Text("7 Days").tag(Period.week)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            // Unrelated to the window's actions: its own glass capsule. It exports everything
            // History keeps, whatever the period.
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                HistoryExportMenu(request: $exportRequest, isEnabled: hasLoaded && !(points.isEmpty && days.isEmpty))
            }
        }
        .modifier(HistoryExporter(request: $exportRequest, target: exportTarget))
        .navigationSubtitle(subtitle)
        .task(
            id: ReloadKey(period: period, source: effectiveSource, isVisible: motion.isVisible),
            name: "HistoryView.reload"
        ) {
            // Reload as new samples arrive, but not while the window can't be seen; it reloads
            // as soon as it can again.
            guard motion.isVisible else { return }
            while !Task.isCancelled {
                await load()
                // About once a minute: the axis creeps forward, so a few seconds either way don't show.
                try? await Task.sleep(for: .seconds(60), tolerance: .seconds(15))
            }
        }
    }

    /// The charts and figures for the loaded period, or why there are none.
    private var periodContent: some View {
        VStack(spacing: 16) {
            if hasLoaded, points.isEmpty {
                ContentUnavailableView {
                    Label("No History Yet", systemImage: "chart.xyaxis.line")
                } description: {
                    if AppSettings.recordsHistory {
                        if case .device = shownSource {
                            Text(
                                "BatteryPulse records an iPhone or iPad every 5 minutes while it's connected by cable.")
                        } else {
                            Text(
                                "BatteryPulse records the battery about once a minute while it runs. Check back in a few minutes."
                            )
                        }
                    } else {
                        Text("Recording is off. Turn it on in Settings → Advanced.")
                    }
                }
                .frame(minHeight: 260)
            } else {
                Card("Charge") { chargeChart }
                Card("Power") { powerChart }
                if points.contains(where: { $0.temperatureCelsius != nil }) {
                    Card("Temperature") { temperatureChart }
                }
                if let statistics { statisticsRow(statistics) }
            }
        }
    }

    // MARK: - Data

    /// The history on screen: the store and source of the last load, taken together, so a source
    /// switched during a load never exports one device's history under another's name. Demo Mode
    /// doesn't change it: History shows what was recorded.
    private var exportTarget: HistoryExportTarget? {
        guard let loadedStore, let loadedSource else { return nil }
        switch loadedSource {
        case .mac:
            return HistoryExportTarget(
                store: loadedStore, source: .mac(ProcessInfo.processInfo.operatingSystemVersion))
        case .device(let key):
            guard let device = devices.rememberedDevice(key) else { return nil }
            return HistoryExportTarget(
                store: loadedStore,
                source: .device(
                    deviceClass: device.deviceClass, productType: device.productType,
                    modelName: IDeviceModelName.name(productType: device.productType), osVersion: device.osVersion))
        }
    }

    private func load() async {
        let period = self.period
        let interval = Diagnostics.begin("history.load", trigger: period == .day ? "day" : "week")
        defer { interval.end() }
        let source = effectiveSource
        let store: HistoryStore
        var end = Date()
        let samples: [HistorySample]
        switch source {
        case .mac:
            store = AppHistory.store
            samples = (try? await store.samples(from: end.addingTimeInterval(-period.length))) ?? []
        case .device(let key):
            // A device is recorded only while it is connected: the axis ends at its last sample,
            // so its last charging session shows.
            store = await devices.historyStore(for: key)
            end = min(end, (try? await store.latestSampleTime()) ?? end)
            samples = (try? await store.samples(from: end.addingTimeInterval(-period.length), to: end)) ?? []
        }
        let points = HistoryPoint.points(from: samples, bucket: period.bucket)
        let spans = HistorySpan.spans(from: samples)
        // Drain and time on battery mean nothing for a device sampled only while on a cable.
        let statistics = samples.isEmpty || source != .mac ? nil : HistoryStatistics(samples: samples)
        let days = (try? await store.dailySummaries()) ?? []
        // A newer period or a hidden window cancelled this load; its data is stale.
        guard !Task.isCancelled else { return }
        // The daily summaries don't depend on the period, so their charts never animate.
        self.days = days
        let apply = {
            self.end = end
            self.points = points
            self.spans = spans
            self.statistics = statistics
            loadedPeriod = period
            loadedSource = source
            loadedStore = store
            hasLoaded = true
        }
        // Only a period or source switch animates. The minute reload never does: it would redraw
        // three charts of up to 1,440 points for nothing. `change` moves the card below to the
        // new height; under Reduce Motion it is `nil` and only the charts fade.
        if let loadedPeriod, loadedPeriod != period || loadedSource != source {
            withAnimation(motion.change, apply)
        } else {
            apply()
        }
    }

    /// The period of the charts on screen.
    private var shownPeriod: Period {
        loadedPeriod ?? period
    }

    /// The source of the charts on screen.
    private var shownSource: HistorySource {
        loadedSource ?? effectiveSource
    }

    private var domain: ClosedRange<Date> {
        end.addingTimeInterval(-shownPeriod.length)...end
    }

    // MARK: - Charts

    /// The legend sits under the chart, clear of the axis labels and the hover readout.
    private var chargeChart: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Chart {
                ForEach(spans) { span in
                    RectangleMark(
                        xStart: .value(ChartKey.start, span.start), xEnd: .value(ChartKey.end, span.end),
                        yStart: .value(ChartKey.bottom, 0), yEnd: .value(ChartKey.top, 100)
                    )
                    // Charging a little stronger than holding the charge.
                    .foregroundStyle(tones.style(span.kind == .charging ? .chargingSpan : .holdingSpan))
                    .accessibilityHidden(true)
                }
                ForEach(points) { point in
                    if let percent = point.percent {
                        LineMark(
                            x: .value("Time", point.time), y: .value("Charge", percent),
                            series: .value(ChartKey.segment, point.segment)
                        )
                        .foregroundStyle(tones.style(.chart(.charge)))
                        .interpolationMethod(.monotone)
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
            .chartOverlay { proxy in
                selectionOverlay(proxy) { point in point.percent.map { formatter.percent($0) } }
            }
            .frame(height: 200)
            Label("On power adapter", systemImage: "square.fill")
                .font(.caption)
                .foregroundStyle(tones.style(.spanLegend))
                .labelStyle(.titleAndIcon)
        }
    }

    @ViewBuilder
    private var powerChart: some View {
        let chart = Chart {
            ForEach(points) { point in
                if let watts = point.batteryWatts {
                    powerLine(point, watts: watts, series: "battery", name: String(localized: "Battery"))
                }
                if let load = point.systemLoadWatts {
                    powerLine(point, watts: load, series: "load", name: String(localized: "Mac"))
                }
            }
            RuleMark(y: .value(ChartKey.zero, 0))
                .foregroundStyle(.secondary.opacity(0.5))
                .accessibilityHidden(true)
        }
        .chartForegroundStyleScale([
            String(localized: "Battery"): tones.color(.chart(.batteryPower)),
            String(localized: "Mac"): tones.color(.chart(.systemLoad)),
        ])
        // A device has the battery's line alone: no legend naming the Mac.
        .chartLegend(shownSource == .mac ? .automatic : .hidden)
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
        .chartOverlay { proxy in
            selectionOverlay(proxy) { point in
                let watts = [point.batteryWatts, point.systemLoadWatts].compactMap { $0 }
                return watts.isEmpty ? nil : watts.map { formatter.watts($0, signed: true) }.joined(separator: " · ")
            }
        }
        .frame(height: 180)
        if tones.isMonochrome {
            // Clear: every line is white, so the Mac's is dashed and fainter, in the legend too.
            chart.chartLineStyleScale([
                String(localized: "Battery"): lineStyle(.batteryPower),
                String(localized: "Mac"): lineStyle(.systemLoad),
            ])
        } else {
            chart
        }
    }

    /// One point of a power line. In Clear the line's dash encodes its series as well as its tone.
    @ChartContentBuilder
    private func powerLine(_ point: HistoryPoint, watts: Double, series: String, name: String) -> some ChartContent {
        let mark = LineMark(
            x: .value("Time", point.time), y: .value("Watts", watts),
            series: .value(ChartKey.series, "\(series)-\(point.segment)")
        )
        .foregroundStyle(by: .value(ChartKey.line, name))
        if tones.isMonochrome {
            mark.lineStyle(by: .value(ChartKey.line, name))
        } else {
            mark
        }
    }

    private func lineStyle(_ line: ChartLine) -> StrokeStyle {
        StrokeStyle(lineWidth: 2, lineCap: .round, dash: tones.dash(for: line).map { CGFloat($0) })
    }

    private var temperatureChart: some View {
        Chart {
            ForEach(points) { point in
                if let celsius = point.temperatureCelsius {
                    LineMark(
                        x: .value("Time", point.time), y: .value("Temperature", celsius),
                        series: .value(ChartKey.segment, point.segment)
                    )
                    .foregroundStyle(tones.style(.chart(.temperature)))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let celsius = value.as(Double.self) { Text(formatter.celsius(celsius)) }
                }
            }
        }
        .chartXAxis { timeAxis }
        .chartXSelection(value: $selectedTime)
        .chartOverlay { proxy in
            selectionOverlay(proxy) { point in point.temperatureCelsius.map { formatter.celsius($0) } }
        }
        .frame(height: 140)
    }

    /// Few ticks on whole hours or days: tick generation is expensive, and labels on odd times
    /// read badly.
    private var timeAxis: some AxisContent {
        let period = shownPeriod
        return AxisMarks(values: period == .day ? .stride(by: .hour, count: 6) : .stride(by: .day)) { _ in
            AxisGridLine()
            AxisValueLabel(
                format: period == .day ? .dateTime.hour() : .dateTime.weekday(.abbreviated), centered: period == .week)
        }
    }

    /// The hover line and readout, drawn over the chart rather than in it, so moving the pointer
    /// redraws only this overlay and not every mark.
    private func selectionOverlay(
        _ proxy: ChartProxy, _ value: @escaping (HistoryPoint) -> String?
    ) -> some View {
        SelectionOverlay(
            proxy: proxy, points: points, selection: $selectedTime, showsDate: shownPeriod == .week, value: value)
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
                    .font(.title3.weight(look.boldNumerals ? .bold : .semibold))
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
                            .foregroundStyle(tones.style(.chart(.capacity)))
                        PointMark(x: .value("Day", entry.date), y: .value("Capacity", capacity))
                            .foregroundStyle(tones.style(.chart(.capacity)))
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
                            .foregroundStyle(tones.style(.chart(.cycles)))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 120)
            }
        }
    }
}

/// Names of internal chart dimensions (segments, series, rectangle edges). Passed as Strings,
/// not literals, so they aren't localization keys; the user-facing ones (Time, Charge, Watts…)
/// are literals and in the catalog, for VoiceOver and Audio Graphs.
private enum ChartKey {
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
private struct SelectionOverlay: View {
    let proxy: ChartProxy
    let points: [HistoryPoint]
    @Binding var selection: Date?
    let showsDate: Bool
    let value: (HistoryPoint) -> String?

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
        .background(.regularMaterial, in: .rect(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
    }
}

/// A daily summary placed at noon of its day.
private struct DayPoint: Identifiable {
    let date: Date
    let day: HistoryDay
    var id: String { day.day }
}
#endif

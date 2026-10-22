#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI
import os

/// Whose history the History page shows: this Mac's, or a remembered iPhone's or iPad's.
/// Nonisolated: the load off the main actor compares it (``HistoryLoad``).
nonisolated enum HistorySource: Hashable {
    case mac
    case device(DeviceKey)
}

/// Battery history: charge and power over the last day or week, figures for that period, and
/// how capacity and cycles change over months. This Mac's, or a remembered iPhone's or iPad's,
/// picked in the toolbar.
struct HistoryView: View {
    /// The period picked in the toolbar.
    @State private var period: HistoryPeriod = .day
    /// The charts and figures on screen, built off the main actor and assigned in one step. Their
    /// period follows ``period`` once that period's samples are loaded, so the charts never draw
    /// the old data on the new period's axis.
    @State private var chart = HistoryChartData(period: .day, end: Date())
    /// The daily summaries, at noon of their days.
    @State private var days: [HistoryDayPoint] = []
    @State private var selectedTime: Date?
    /// The Export menu's pick while its file is prepared.
    @State private var exportRequest: HistoryExportRequest?
    /// The source picked in the toolbar; Show in History on a device page sets it too.
    @Binding private var source: HistorySource
    /// Settings → Advanced → Record battery history, observed so the empty page's sentence
    /// follows it at once.
    @AppStorage(AppSettings.recordHistoryKey) private var recordsHistory = true
    /// The source of the data on screen, like ``chart``'s period; `nil` until the first load.
    @State private var loadedSource: HistorySource?
    /// The store the data on screen came from, for exporting what History shows.
    @State private var loadedStore: HistoryStore?
    @Environment(IDeviceMonitor.self) private var devices
    @Environment(DemoController.self) private var demo
    @Environment(\.motion) private var motion
    @Environment(\.windowLook) private var look
    private let formatter = BatteryFormatter.app

    init(source: Binding<HistorySource>) {
        _source = source
    }

    /// Restarts the reload loop when the period or the source changes or the window is shown
    /// again.
    private struct ReloadKey: Equatable {
        var period: HistoryPeriod
        var source: HistorySource
        var isVisible: Bool
    }

    /// What the charts show at a time: switching either crossfades them.
    private struct ShownKey: Hashable {
        var period: HistoryPeriod
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
                    Card("Battery Health") { HealthTrendCharts(days: days) }
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
                    Text("24 Hours").tag(HistoryPeriod.day)
                    Text("7 Days").tag(HistoryPeriod.week)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            // Unrelated to the window's actions: its own glass capsule. It exports everything
            // History keeps, whatever the period.
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                HistoryExportMenu(
                    request: $exportRequest, isEnabled: hasLoaded && !(chart.points.isEmpty && days.isEmpty))
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
            if hasLoaded, chart.points.isEmpty {
                ContentUnavailableView {
                    Label("No History Yet", systemImage: "chart.xyaxis.line")
                } description: {
                    if recordsHistory {
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
                Card("Charge") {
                    ChargeChart(data: chart, period: shownPeriod, domain: domain, selection: $selectedTime)
                }
                Card("Power") {
                    PowerChart(
                        data: chart, period: shownPeriod, domain: domain, showsLegend: shownSource == .mac,
                        selection: $selectedTime)
                }
                if chart.hasTemperature {
                    Card("Temperature") {
                        TemperatureChart(data: chart, period: shownPeriod, domain: domain, selection: $selectedTime)
                    }
                }
                if let statistics = chart.statistics { statisticsRow(statistics) }
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

    /// Reads and builds off the main actor (``HistoryLoad``); here only the assignment runs.
    private func load() async {
        let period = self.period
        let interval = Diagnostics.begin("history.load", trigger: period == .day ? "day" : "week")
        defer { interval.end() }
        let source = effectiveSource
        let store: HistoryStore
        switch source {
        case .mac: store = AppHistory.store
        case .device(let key): store = await devices.historyStore(for: key)
        }
        let loaded = await HistoryLoad.read(store, source: source, period: period, now: Date())
        // A newer period or a hidden window cancelled this load; its data is stale.
        guard !Task.isCancelled else { return }
        // The daily summaries don't depend on the period, so their charts never animate.
        days = loaded.days
        let apply = {
            chart = loaded.chart
            loadedSource = source
            loadedStore = store
        }
        // Only a period or source switch animates. The minute reload never does: it would redraw
        // three charts of up to 1,440 points for nothing. `change` moves the card below to the
        // new height; under Reduce Motion it is `nil` and only the charts fade.
        if let loadedSource, chart.period != period || loadedSource != source {
            withAnimation(motion.change, apply)
        } else {
            apply()
        }
    }

    /// Whether a load has finished, so an empty chart means no history rather than not yet read.
    private var hasLoaded: Bool {
        loadedSource != nil
    }

    /// The period of the charts on screen.
    private var shownPeriod: HistoryPeriod {
        hasLoaded ? chart.period : period
    }

    /// The source of the charts on screen.
    private var shownSource: HistorySource {
        loadedSource ?? effectiveSource
    }

    private var domain: ClosedRange<Date> {
        chart.end.addingTimeInterval(-shownPeriod.length)...chart.end
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
}

/// One load of the History page: the period's charts and figures, and the daily summaries.
/// Nonisolated: it reads and builds off the main actor.
private nonisolated struct HistoryLoad: Sendable {
    var chart: HistoryChartData
    var days: [HistoryDayPoint]

    /// Reads `source`'s samples for `period` up to `now` and its daily summaries from `store`, and
    /// builds the charts from them, off the main actor.
    @concurrent
    static func read(
        _ store: HistoryStore, source: HistorySource, period: HistoryPeriod, now: Date
    ) async -> HistoryLoad {
        var end = now
        let samples: [HistorySample]
        switch source {
        case .mac:
            let start = end.addingTimeInterval(-period.length)
            samples = await logged("the samples") { try await store.samples(from: start) } ?? []
        case .device:
            // A device is recorded only while it is connected: the axis ends at its last sample,
            // so its last charging session shows.
            let latest = await logged("the latest sample") { try await store.latestSampleTime() ?? now } ?? now
            end = min(now, latest)
            let (start, last) = (end.addingTimeInterval(-period.length), end)
            samples = await logged("the samples") { try await store.samples(from: start, to: last) } ?? []
        }
        let days = await logged("the daily summaries") { try await store.dailySummaries() } ?? []
        return HistoryLoad(
            // Drain and time on battery mean nothing for a device sampled only while on a cable.
            chart: .make(samples: samples, period: period, end: end, includesStatistics: source == .mac),
            days: HistoryDayPoint.points(from: days))
    }

    /// What `body` returns, or `nil` once its failure is logged; the page then shows no history.
    /// Only an unreadable file or folder, or an I/O error, throws (a corrupt line is skipped). While
    /// it lasts, a visible History page logs it once a minute. `what` is static text; the error's
    /// domain and code are public, its description, which can name a path, is not.
    private static func logged<Value>(_ what: String, _ body: () async throws -> Value) async -> Value? {
        do {
            return try await body()
        } catch {
            let error = error as NSError
            Diagnostics.history.error(
                "Reading \(what, privacy: .public) failed (\(error.domain, privacy: .public) \(error.code)): \(error.localizedDescription)"
            )
            return nil
        }
    }
}
#endif

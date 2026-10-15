#if os(macOS)
import Accessibility
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

enum SidebarItem: Hashable, Identifiable {
    case overview, power, health, history
    /// Developer section: raw data and Demo Mode.
    case developer, demo
    /// Devices section: an iPhone's or iPad's page, or the intro row when there is none.
    case device(DeviceKey)
    case devicesIntro

    var id: Self { self }

    static let pages: [SidebarItem] = [.overview, .power, .health, .history]
    static let developerPages: [SidebarItem] = [.developer, .demo]

    /// Whether the page shows the live reading. History comes from disk, Demo Mode from the demo
    /// and the Devices section from other devices, so the main window doesn't poll the battery
    /// while they are shown.
    var showsLiveValues: Bool {
        switch self {
        case .overview, .power, .health, .developer: true
        case .history, .demo, .device, .devicesIntro: false
        }
    }

    /// A `var` with literal cases: the catalog test finds the keys here. A device page shows the
    /// device's name instead (`MainView.navigationTitle`).
    var title: LocalizedStringKey {
        switch self {
        case .overview: "Overview"
        case .power: "Power"
        case .health: "Health"
        case .history: "History"
        case .developer: "Raw Data"
        case .demo: "Demo Mode"
        case .devicesIntro: "iPhone and iPad"
        case .device: "iPhone and iPad"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .power: "bolt.fill"
        case .health: "heart.text.square"
        case .history: "chart.xyaxis.line"
        case .developer: "tablecells"
        case .demo: "play.rectangle.on.rectangle"
        case .devicesIntro: "ipad.and.iphone"
        case .device: "iphone"
        }
    }

    /// The page as scene storage keeps it: a name, or `device:` and the device's key.
    var storageKey: String {
        switch self {
        case .overview: "overview"
        case .power: "power"
        case .health: "health"
        case .history: "history"
        case .developer: "developer"
        case .demo: "demo"
        case .devicesIntro: "devices"
        case .device(let key): Self.devicePrefix + key.rawValue
        }
    }

    init?(storageKey: String) {
        if storageKey.hasPrefix(Self.devicePrefix) {
            guard let key = DeviceKey(rawValue: String(storageKey.dropFirst(Self.devicePrefix.count))) else {
                return nil
            }
            self = .device(key)
            return
        }
        let named: [SidebarItem] = Self.pages + Self.developerPages + [.devicesIntro]
        guard let item = named.first(where: { $0.storageKey == storageKey }) else { return nil }
        self = item
    }

    private static let devicePrefix = "device:"
}

/// The main window: a sidebar of sections and their content.
struct MainView: View {
    let monitor: BatteryMonitor
    @Environment(DemoController.self) private var demo
    @Environment(IDeviceMonitor.self) private var devices
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.motion) private var motion
    @AppStorage(AppSettings.showDeveloperKey) private var showsDeveloper = false
    /// The page shown, kept per window: a window style change rebuilds the window's content, and
    /// the page stays.
    @SceneStorage("mainSelection") private var storedSelection = SidebarItem.overview.storageKey
    /// Whose history the History page shows; kept while switching pages.
    @State private var historySource: HistorySource = .mac
    private let formatter = BatteryFormatter.app

    /// The Devices section's iPhones and iPads: in Demo Mode only the simulated one, so
    /// screenshots never show a real owner's device name.
    private var deviceEntries: [IDeviceEntry] {
        AppDevices.shownEntries(devices, demo: demo)
    }

    /// The rows slide in and out when a device attaches or is forgotten; keyed on the IDs, never
    /// on the batteries.
    private var deviceRowIDs: [DeviceKey] {
        deviceEntries.map(\.id)
    }

    private var rememberedIDs: [DeviceKey] {
        devices.remembered.map(\.id)
    }

    private var selection: SidebarItem {
        get { SidebarItem(storageKey: storedSelection) ?? .overview }
        nonmutating set { storedSelection = newValue.storageKey }
    }

    /// Show in History on a device page: History with that device's source.
    private func showInHistory(_ key: DeviceKey) {
        historySource = .device(key)
        selection = .history
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { selection }, set: { selection = $0 })) {
                ForEach(SidebarItem.pages) { item in
                    Label(item.title, systemImage: item.symbol)
                }
                Section("Devices") {
                    if deviceEntries.isEmpty {
                        Label(SidebarItem.devicesIntro.title, systemImage: SidebarItem.devicesIntro.symbol)
                            .tag(SidebarItem.devicesIntro)
                    } else {
                        ForEach(deviceEntries) { entry in
                            DeviceRow(entry: entry, formatter: formatter)
                                .tag(SidebarItem.device(entry.id))
                        }
                    }
                    // Other kinds of devices follow the iPhones and iPads, one row each.
                }
                if showsDeveloper {
                    Section("Developer") {
                        ForEach(SidebarItem.developerPages) { item in
                            Label(item.title, systemImage: item.symbol)
                        }
                    }
                }
            }
            // The Developer section slides in and out when it is turned on or off in Settings; under
            // Reduce Motion it appears and goes at once.
            .animation(motion.change, value: showsDeveloper)
            .animation(motion.change, value: deviceRowIDs)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            // Switching pages is the most frequent action here, so it gets the least motion: a
            // 0.15 s fade, no slide. The ZStack keeps the old and the new page on top of each
            // other while they fade.
            ZStack {
                MainDetail(
                    monitor: monitor, selection: selection, historySource: $historySource,
                    showInHistory: showInHistory
                )
                .id(selection)
                .transition(.opacity)
            }
            .animation(motion.quickFade, value: selection)
            .navigationTitle(navigationTitle)
            // Floats over every page while Demo Mode is on; content scrolls under it with the
            // system's scroll edge effect.
            .safeAreaBar(edge: .bottom) {
                DemoControlBar()
            }
            // The minimum size belongs on the column: a minimum on the whole split view makes
            // the sidebar's show/hide animation stutter.
            .frame(minWidth: 520, minHeight: 540)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    CopyReportButton(monitor: monitor, selection: selection)
                }
                // Unrelated actions: each gets its own glass capsule.
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) {
                    Button("Compact Window", systemImage: "arrow.down.right.and.arrow.up.left") {
                        WindowOpener.switchWindowStyle(compact: true)
                        dismissWindow(id: WindowID.main)
                    }
                    .help("Show the essentials in a small window")
                }
            }
        }
        // A restored page of the Developer section shows only while the section is on.
        .onAppear {
            if !showsDeveloper, SidebarItem.developerPages.contains(selection) { selection = .overview }
        }
        // DemoController stops the demo itself when the section is hidden.
        .onChange(of: showsDeveloper) { _, shows in
            if !shows, SidebarItem.developerPages.contains(selection) { selection = .overview }
        }
        // A device page whose device went (forgotten, unplugged while never remembered, the demo
        // ended) shows the first device left, else the intro; the intro gives way to the first
        // device that appears.
        .onChange(of: deviceRowIDs) { _, ids in
            switch selection {
            case .device(let key) where !ids.contains(key):
                selection = ids.first.map(SidebarItem.device) ?? .devicesIntro
            case .devicesIntro:
                if let first = ids.first { selection = .device(first) }
            default:
                break
            }
        }
        // A forgotten device's history is gone: History goes back to this Mac.
        .onChange(of: rememberedIDs) { _, ids in
            if case .device(let key) = historySource, !ids.contains(key) { historySource = .mac }
        }
        // The demo tour switches pages by itself, but never to a hidden one. The page changes in
        // one transaction with the demo's data; the detail still fades through `quickFade` when
        // `change` is off (Reduce Motion), and the sidebar selection then moves at once.
        .onChange(of: demo.pageRequest) { _, request in
            guard let request else { return }
            let isHidden = !showsDeveloper && SidebarItem.developerPages.contains(request.page)
            withAnimation(motion.change) { selection = isHidden ? .overview : request.page }
        }
        // Polls every 2 s while the window can be seen and the page shows live values.
        .liveRefresh(monitor, every: .seconds(2), client: "main", isEnabled: selection.showsLiveValues)
        .trackedWindow(WindowID.main)
    }

    /// A device page is titled with the device's name, which is data, not a catalog key.
    private var navigationTitle: Text {
        if case .device(let key) = selection, let entry = deviceEntries.first(where: { $0.id == key }) {
            return DeviceText.displayName(entry)
        }
        return Text(selection.title)
    }
}

/// An iPhone or iPad in the sidebar: its name and, while connected, its charge.
private struct DeviceRow: View {
    let entry: IDeviceEntry
    let formatter: BatteryFormatter

    var body: some View {
        let isConnected = entry.connection != nil
        let charge: Text? =
            isConnected ? entry.battery?.chargePercent.map { Text(verbatim: formatter.percent($0)) } : nil
        Label {
            DeviceText.displayName(entry)
        } icon: {
            Image(systemName: IDeviceModel.symbolName(deviceClass: entry.deviceClass))
        }
        .badge(charge)
        // Dimmed while not connected: the values are the last ones read.
        .foregroundStyle(isConnected ? HierarchicalShapeStyle.primary : .secondary)
        .help(lastSeen)
    }

    /// "Last seen 14:32" for a device that isn't connected.
    private var lastSeen: Text {
        guard entry.connection == nil, let date = entry.lastSeen else { return Text(verbatim: "") }
        return Text("Last seen \(DeviceText.date(date))")
    }
}

/// The selected page. A separate view, so live updates re-render only the detail column and not
/// the split view, sidebar and toolbar.
private struct MainDetail: View {
    let monitor: BatteryMonitor
    let selection: SidebarItem
    @Binding var historySource: HistorySource
    let showInHistory: @MainActor (DeviceKey) -> Void

    var body: some View {
        // History and the Devices section come from disk and other devices, so they show even
        // when this Mac has no battery or no reading yet.
        switch selection {
        case .demo:
            DemoView()
        case .history:
            HistoryView(source: $historySource)
        case .devicesIntro:
            DevicesIntroView()
        case .device(let key):
            DevicePage(key: key, showInHistory: showInHistory)
        case .overview, .power, .health, .developer:
            snapshotPage
        }
    }

    @ViewBuilder
    private var snapshotPage: some View {
        if let snapshot = monitor.snapshot {
            switch selection {
            case .overview: OverviewView(snapshot: snapshot)
            case .power: PowerView(snapshot: snapshot)
            case .health: HealthView(snapshot: snapshot)
            default: DeveloperView(monitor: monitor)
            }
        } else if monitor.hasBattery == false {
            ContentUnavailableView(
                "No Battery",
                systemImage: "battery.0percent",
                description: Text("This Mac has no internal battery.")
            )
        } else {
            ProgressView()
        }
    }
}

/// A device's page, from the entry the Devices section shows for its key.
private struct DevicePage: View {
    let key: DeviceKey
    let showInHistory: @MainActor (DeviceKey) -> Void
    @Environment(IDeviceMonitor.self) private var devices
    @Environment(DemoController.self) private var demo

    var body: some View {
        if let entry = AppDevices.shownEntries(devices, demo: demo).first(where: { $0.id == key }) {
            DeviceView(entry: entry, showInHistory: showInHistory)
        } else {
            DevicesIntroView()
        }
    }
}

private struct CopyReportButton: View {
    let monitor: BatteryMonitor
    let selection: SidebarItem
    @Environment(IDeviceMonitor.self) private var devices
    @Environment(DemoController.self) private var demo
    @Environment(\.motion) private var motion
    /// The icon shows a checkmark for a moment after copying.
    @State private var copied = false

    var body: some View {
        Button(action: copyReport) {
            Label {
                Text("Copy Report")
            } icon: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(motion.symbolSwap)
            }
        }
        .disabled(!canCopy)
        .help(help)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(motion.crossfade) { copied = false }
        }
    }

    /// A report of simulated data would mislead a bug report. A device's report is of this
    /// session's last read, so it needs one.
    private var canCopy: Bool {
        switch selection {
        case .device(let key):
            !demo.isActive && devices.entries.contains { $0.id == key && $0.hasCapture }
        case .devicesIntro:
            false
        default:
            monitor.snapshot != nil && !monitor.isOverridden
        }
    }

    private var help: Text {
        switch selection {
        case .device:
            if demo.isActive { return Text("Not available in Demo Mode") }
            if !canCopy { return Text("Connect the device to copy a report") }
            return Text("Copy a plain-text report without serial numbers")
        default:
            if monitor.isOverridden { return Text("Not available in Demo Mode") }
            return Text("Copy a plain-text report without serial numbers")
        }
    }

    private func copyReport() {
        let text: String
        if case .device(let key) = selection {
            // No identifier and no owner name: the capture is redacted first.
            guard !demo.isActive, let capture = devices.capture(for: key) else { return }
            text = IDeviceReport.text(for: capture.redacted)
        } else {
            // Simulated data would mislead a bug report, and Demo Mode never triggers a read.
            guard !monitor.isOverridden else { return }
            // History and Demo Mode don't poll the battery, so the last reading can be minutes old:
            // take a fresh one for the report.
            monitor.refresh()
            guard let snapshot = monitor.snapshot else { return }
            text = BatteryReport.text(for: snapshot)
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        withAnimation(motion.crossfade) { copied = true }
        AccessibilityNotification.Announcement(String(localized: "Report copied")).post()
    }
}
#endif

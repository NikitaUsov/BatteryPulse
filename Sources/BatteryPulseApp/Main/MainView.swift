#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview, power, health, history
    /// Developer section: raw data and Demo Mode.
    case developer, demo

    var id: Self { self }

    static let pages: [SidebarItem] = [.overview, .power, .health, .history]
    static let developerPages: [SidebarItem] = [.developer, .demo]

    var title: LocalizedStringKey {
        switch self {
        case .overview: "Overview"
        case .power: "Power"
        case .health: "Health"
        case .history: "History"
        case .developer: "Raw Data"
        case .demo: "Demo Mode"
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
        }
    }
}

/// The main window: a sidebar of sections and their content.
struct MainView: View {
    let monitor: BatteryMonitor
    @Environment(DemoController.self) private var demo
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(AppSettings.showDeveloperKey) private var showsDeveloper = false
    @State private var selection: SidebarItem = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.pages) { item in
                    Label(item.title, systemImage: item.symbol)
                }
                if showsDeveloper {
                    Section("Developer") {
                        ForEach(SidebarItem.developerPages) { item in
                            Label(item.title, systemImage: item.symbol)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            MainDetail(monitor: monitor, selection: selection)
                .navigationTitle(selection.title)
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
                        CopyReportButton(monitor: monitor)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Compact Window", systemImage: "arrow.down.right.and.arrow.up.left") {
                            WindowOpener.switchWindowStyle(compact: true)
                            dismissWindow(id: WindowID.main)
                        }
                        .help("Show the essentials in a small window")
                    }
                }
        }
        // DemoController stops the demo itself when the section is hidden.
        .onChange(of: showsDeveloper) { _, shows in
            if !shows, SidebarItem.developerPages.contains(selection) { selection = .overview }
        }
        // The demo tour switches pages by itself, but never to a hidden one.
        .onChange(of: demo.pageRequest) { _, request in
            guard let request else { return }
            let isHidden = !showsDeveloper && SidebarItem.developerPages.contains(request.page)
            selection = isHidden ? .overview : request.page
        }
        .onAppear { monitor.setLiveRefreshInterval(.seconds(2), for: "main") }
        .onDisappear { monitor.setLiveRefreshInterval(nil, for: "main") }
        .trackedWindow(WindowID.main)
    }

}

/// The selected page. A separate view, so live updates re-render only the detail column and not
/// the split view, sidebar and toolbar.
private struct MainDetail: View {
    let monitor: BatteryMonitor
    let selection: SidebarItem

    var body: some View {
        if selection == .demo {
            DemoView()
        } else if selection == .history {
            // History is on disk, so it shows even when there is no live reading.
            HistoryView()
        } else if let snapshot = monitor.snapshot {
            switch selection {
            case .overview: OverviewView(snapshot: snapshot)
            case .power: PowerView(snapshot: snapshot)
            case .health: HealthView(snapshot: snapshot)
            case .developer, .demo, .history: DeveloperView(monitor: monitor)
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

private struct CopyReportButton: View {
    let monitor: BatteryMonitor

    var body: some View {
        // A report of simulated data would mislead a bug report.
        Button("Copy Report", systemImage: "doc.on.doc", action: copyReport)
            .disabled(monitor.snapshot == nil || monitor.isOverridden)
            .help(
                monitor.isOverridden
                    ? Text("Not available in Demo Mode") : Text("Copy a plain-text report without serial numbers"))
    }

    private func copyReport() {
        guard let snapshot = monitor.snapshot, !monitor.isOverridden else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(BatteryReport.text(for: snapshot), forType: .string)
    }
}
#endif

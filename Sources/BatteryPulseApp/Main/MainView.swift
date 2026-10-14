#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview, power, health, developer

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "Overview"
        case .power: "Power"
        case .health: "Health"
        case .developer: "Developer"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .power: "bolt.fill"
        case .health: "heart.text.square"
        case .developer: "hammer"
        }
    }
}

/// The main window: a sidebar of sections and their content.
struct MainView: View {
    let monitor: BatteryMonitor
    @AppStorage(AppSettings.showDeveloperKey) private var showsDeveloper = false
    @State private var selection: SidebarItem = .overview

    private var items: [SidebarItem] {
        SidebarItem.allCases.filter { $0 != .developer || showsDeveloper }
    }

    var body: some View {
        NavigationSplitView {
            List(items, selection: $selection) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            MainDetail(monitor: monitor, selection: selection)
                .navigationTitle(selection.title)
                // The minimum size belongs on the column: a minimum on the whole split view makes
                // the sidebar's show/hide animation stutter.
                .frame(minWidth: 520, minHeight: 540)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        CopyReportButton(monitor: monitor)
                    }
                }
        }
        .onChange(of: showsDeveloper) { _, shows in
            if !shows, selection == .developer { selection = .overview }
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
        if let snapshot = monitor.snapshot {
            switch selection {
            case .overview: OverviewView(snapshot: snapshot)
            case .power: PowerView(snapshot: snapshot)
            case .health: HealthView(snapshot: snapshot)
            case .developer: DeveloperView(monitor: monitor)
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
        Button("Copy Report", systemImage: "doc.on.doc", action: copyReport)
            .disabled(monitor.snapshot == nil)
            .help("Copy a plain-text report without serial numbers")
    }

    private func copyReport() {
        guard let snapshot = monitor.snapshot else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(BatteryReport.text(for: snapshot), forType: .string)
    }
}
#endif

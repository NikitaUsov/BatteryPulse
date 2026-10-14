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
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 260)
        } detail: {
            detail
                .navigationTitle(selection.title)
        }
        .frame(minWidth: 720, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Copy Report", systemImage: "doc.on.doc", action: copyReport)
                    .disabled(monitor.snapshot == nil)
                    .help("Copy a plain-text report without serial numbers")
            }
        }
        .onChange(of: showsDeveloper) { _, shows in
            if !shows, selection == .developer { selection = .overview }
        }
        .onAppear { monitor.setLiveRefreshInterval(.seconds(2), for: "main") }
        .onDisappear { monitor.setLiveRefreshInterval(nil, for: "main") }
        .trackedWindow(WindowID.main)
    }

    @ViewBuilder
    private var detail: some View {
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

    private func copyReport() {
        guard let snapshot = monitor.snapshot else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(BatteryReport.text(for: snapshot), forType: .string)
    }
}
#endif

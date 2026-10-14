#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI

/// The status item: a battery symbol plus percentage and/or power, as configured.
struct MenuBarLabel: View {
    let monitor: BatteryMonitor
    @AppStorage(AppSettings.menuBarStyleKey) private var style: MenuBarStyle = .percent

    var body: some View {
        let title = BatteryPresentation.menuBarTitle(for: monitor.snapshot, style: style)
        Image(systemName: BatteryPresentation.symbolName(for: monitor.snapshot))
            .onChange(of: style, initial: true) { _, style in
                // Power changes without OS notifications, so poll gently while it is shown.
                monitor.setLiveRefreshInterval(style.showsPower ? .seconds(10) : nil, for: "menuBar")
            }
        if !title.isEmpty {
            Text(title)
        }
    }
}
#endif

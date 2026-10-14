#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

/// The status item: a battery symbol plus percentage and/or power, as configured.
struct MenuBarLabel: View {
    let monitor: BatteryMonitor
    @Environment(DemoController.self) private var demo
    @AppStorage(AppSettings.menuBarStyleKey) private var style: MenuBarStyle = .percent
    @AppStorage(AppSettings.menuBarIconKey) private var iconStyle: MenuBarIconStyle = .standard
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let title = BatteryPresentation.menuBarTitle(for: monitor.snapshot, style: style, formatter: .app)
        Group {
            if demo.isActive {
                // The values next to it are simulated.
                Image(systemName: "play.rectangle.on.rectangle")
                    .accessibilityLabel("Demo Mode")
            }
            if BatteryPresentation.showsIcon(iconStyle, title: title) {
                icon(BatteryPresentation.symbolName(for: monitor.snapshot))
            }
            if !title.isEmpty {
                Text(title)
            }
        }
        .onAppear { WindowOpener.openWindow = openWindow }
        .onChange(of: style, initial: true) { _, style in
            // Power changes without OS notifications, so poll gently while it is shown.
            monitor.setLiveRefreshInterval(style.showsPower ? .seconds(10) : nil, for: "menuBar")
        }
        .onDisappear { monitor.setLiveRefreshInterval(nil, for: "menuBar") }
    }

    @ViewBuilder
    private func icon(_ symbolName: String) -> some View {
        if iconStyle == .large, let image = Self.largeSymbol(symbolName) {
            Image(nsImage: image)
        } else {
            Image(systemName: symbolName)
        }
    }

    /// The menu bar draws `Image(systemName:)` at a fixed size, so the large variant is
    /// pre-rendered at a bigger point size. Template images keep the menu bar's tinting.
    private static func largeSymbol(_ name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}
#endif

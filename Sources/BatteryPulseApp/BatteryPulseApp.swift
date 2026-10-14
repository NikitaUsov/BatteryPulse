#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

@main
struct BatteryPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor: BatteryMonitor
    private let showsWelcome: Bool

    init() {
        let monitor = BatteryMonitor(provider: MacBatteryProvider())
        monitor.start()
        _monitor = State(initialValue: monitor)
        showsWelcome = AppSettings.shouldShowWelcomeAtLaunch
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Window("Welcome to BatteryPulse", id: WindowID.welcome) {
            WelcomeView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(showsWelcome ? .presented : .suppressed)
        .restorationBehavior(.disabled)

        Window("Battery Details", id: WindowID.details) {
            DetailsView(monitor: monitor)
        }
        .defaultSize(width: 520, height: 680)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
        }
    }
}

enum WindowID {
    static let welcome = "welcome"
    static let details = "details"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only: no Dock icon. The packaged app also sets LSUIElement, but `swift run`
        // launches a bare executable without an Info.plist.
        NSApp.setActivationPolicy(.accessory)
    }
}
#else
/// The app is macOS-only; this stub keeps `swift build` working on Linux.
@main
enum BatteryPulseApp {
    static func main() {
        print("BatteryPulse is a macOS menu-bar app. Try `swift run bpulse` for the report.")
    }
}
#endif

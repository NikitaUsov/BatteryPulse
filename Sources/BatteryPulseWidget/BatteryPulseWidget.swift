#if os(macOS)
import BatteryCore
import SwiftUI
import WidgetKit

/// The widget extension. SwiftPM builds it as a plain executable that `scripts/build-app.sh`
/// wraps into `BatteryPulse.app/Contents/PlugIns/BatteryPulseWidget.appex`. It is linked with
/// `-e _NSExtensionMain` (see Package.swift); `@main` keeps the bundle in the binary.
@main
struct BatteryPulseWidgets: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
    }
}

/// The Battery widget: 0.6.x's kind string, now configured through ``BatteryWidgetIntent``, whose
/// defaults draw 0.6.x's widget. A widget placed before 0.7 keeps its place and its look, as long
/// as WidgetKit fetches the new descriptor from the new extension at the version change (the
/// installer ends the old one right before the swap).
struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: BatteryWidgetKind.battery, intent: BatteryWidgetIntent.self, provider: BatteryTimelineProvider()
        ) { entry in
            BatteryWidgetRoot(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Battery")
        .description("Charge, time remaining and the details you choose.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#else
// Widgets exist on macOS only; this keeps `swift build` working on Linux.
@main
enum BatteryPulseWidgetStub {
    static func main() {
        print("BatteryPulseWidget is a macOS widget extension.")
    }
}
#endif

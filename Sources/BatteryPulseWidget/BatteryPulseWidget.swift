#if os(macOS)
import BatteryCore
import SwiftUI
import WidgetKit

/// The widget extension. SwiftPM builds it as a plain executable that `scripts/build-app.sh`
/// wraps into `BatteryPulse.app/Contents/PlugIns/BatteryPulseWidget.appex`. It is linked with
/// `-e _NSExtensionMain` (see scripts/build-app.sh); `@main` keeps the bundle in the binary.
@main
struct BatteryPulseWidgets: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
        AccessoriesWidget()
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
        // No extra large: the look check left it out of 0.7, and a family can be added later
        // but never removed. Its views come back with it; BatteryCore keeps its plan.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// The Accessories widget: the batteries of the connected keyboards, mice, trackpads and
/// headphones, which the extension reads itself, configured through ``AccessoriesWidgetIntent``.
/// A family can be added later but never removed.
struct AccessoriesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKindID.accessories.rawValue, intent: AccessoriesWidgetIntent.self,
            provider: AccessoriesTimelineProvider()
        ) { entry in
            AccessoriesWidgetRoot(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Accessories")
        .description("Batteries of your keyboard, mouse, trackpad and headphones.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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

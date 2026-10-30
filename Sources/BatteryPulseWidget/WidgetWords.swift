#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

extension EnvironmentValues {
    /// Where the widget's words come from: `nil` for the extension's own tables. The previews set
    /// one language's compiled table, so they show the widget in that language.
    @Entry var widgetStrings: Bundle? = nil
}

/// Every SF Symbol the widget draws, hidden from VoiceOver, which would read the symbol's name
/// rather than what it means here (0.6.1's level symbol read "Three-Quarter-Charged Battery" at
/// 80 %): the words beside it, or its element's label, say that. A glyph takes the accent colour
/// in the accented rendering mode (`.accented`); the others stay in the default group.
func decorativeSymbol(_ name: String, accentedMode: WidgetAccentedRenderingMode? = nil) -> some View {
    Image(systemName: name)
        .widgetAccentedRenderingMode(accentedMode)
        .accessibilityHidden(true)
}

extension View {
    /// One VoiceOver element with the label the plan built (``WidgetAccessibility`` in BatteryCore),
    /// in the widget's language. The time left keeps the system's own text, which counts down.
    @ViewBuilder func widgetElement(_ label: WidgetSpokenLabel, strings: Bundle?) -> some View {
        if let text = label.text({ (strings ?? .main).localizedString(forKey: $0, value: nil, table: nil) }) {
            accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: text))
        } else {
            accessibilityElement(children: .combine)
        }
    }
}

extension BatteryPresentation.LevelTier {
    /// The level colours of 0.6.x.
    var color: Color {
        switch self {
        case .normal: .green
        case .low: .orange
        case .critical: .red
        }
    }
}

/// A word of the catalog in the widget's language: `resource`'s key, looked up in `strings`.
func widgetText(_ resource: LocalizedStringResource, _ strings: Bundle?) -> Text {
    Text(LocalizedStringKey(resource.key), bundle: strings)
}

// The widget's words, as resources so the previews' tests can compare their keys with the ones
// VoiceOver's labels use (BatteryCore's `WidgetAccessibility`).

extension WidgetStateWord {
    var title: LocalizedStringResource {
        switch self {
        case .charging: "Charging"
        case .onBattery: "On battery"
        case .fullyCharged: "Fully charged"
        case .chargingOnHold: "Charging on hold"
        case .notCharging: "Not charging"
        case .unknown: "Unknown"
        }
    }
}

extension WidgetCondition {
    /// The app's words for the condition.
    var title: LocalizedStringResource {
        switch self {
        case .normal: "Normal"
        case .fair: "Fair"
        case .poor: "Poor"
        case .checkBattery: "Check Battery"
        case .serviceRecommended: "Service Recommended"
        // Shown as macOS reports it (text(_:)), never looked up.
        case .other(let raw): LocalizedStringResource(stringLiteral: raw)
        }
    }

    /// The condition's words; one the app has no words for, as macOS reports it.
    func text(_ strings: Bundle?) -> Text {
        if case .other(let raw) = self { Text(verbatim: raw) } else { widgetText(title, strings) }
    }
}

extension ThermalState {
    /// The app's words for the thermal state ("High", "Critical").
    var title: LocalizedStringResource {
        switch self {
        case .nominal: "Normal"
        case .fair: "Elevated"
        case .serious: "High"
        case .critical: "Critical"
        }
    }
}
#endif

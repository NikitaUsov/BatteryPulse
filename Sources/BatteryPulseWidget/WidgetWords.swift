#if os(macOS)
import BatteryCore
import BatterySource
import Foundation
import SwiftUI
import WidgetKit
import os

extension EnvironmentValues {
    /// Where the widget's words come from: the table of the language it draws in
    /// (``WidgetLanguageTable``), English's included; `nil`, without a feed, for the extension's
    /// own tables, which follow the Mac's language.
    @Entry var widgetStrings: Bundle? = nil
}

/// The language a widget draws in, chosen by BatteryPulse's own languages in the feed
/// (``WidgetLanguage``), so a language chosen for BatteryPulse alone reaches the widgets: its
/// words, the locale its system text follows, and its numbers' formatter. Each timeline resolves
/// it once, and its root view sets it for everything below (`widgetLanguage(_:)`).
///
/// The words come from that language's `.lproj` folder in the extension, as a bundle of its own
/// whose table is at its top, as the previews' are. English's holds no table while every English
/// text is its own key (scripts/build-app.sh), so each key reads as its own text: the extension's
/// own tables would follow the Mac's language and draw Russian on a Russian Mac. Without a feed,
/// or without the language's folder, the widget draws in the extension's own language, as 0.7.0
/// did.
struct WidgetLanguageTable: Sendable {
    /// The localization drawn ("en", "ru"); `nil` for the extension's own language.
    let localization: String?
    /// `nil` for the extension's own tables.
    let strings: Bundle?
    /// `nil` for the Mac's locale.
    let locale: Locale?
    let formatter: BatteryFormatter

    /// The extension's own language: its own tables, the Mac's locale and formatter.
    static let extensionOwn = WidgetLanguageTable(localization: nil, strings: nil, locale: nil, formatter: .widget)

    /// `localization`'s table in `resources`, the folder that holds the `.lproj` folders, in the
    /// Mac's region (`mac`); the extension's own language for `nil` or a folder that is missing.
    static func make(_ localization: String?, resources: URL?, mac: Locale = .autoupdatingCurrent)
        -> WidgetLanguageTable
    {
        guard let localization, let resources,
            let strings = Bundle(url: resources.appendingPathComponent(localization + ".lproj", isDirectory: true))
        else { return .extensionOwn }
        let locale = WidgetLanguage.locale(localization, mac: mac)
        return WidgetLanguageTable(
            localization: localization, strings: strings, locale: locale,
            formatter: .widget(locale: locale, strings: strings))
    }

    /// The language a state of the feed chooses among `localizations`, the widget's own, whose
    /// folders are in `resources`.
    static func chosen(
        by state: WidgetFeedState?, localizations: [String], development: String?, resources: URL?,
        mac: Locale = .autoupdatingCurrent
    ) -> WidgetLanguageTable {
        let localization = WidgetLanguage.localization(
            for: state?.feed?.languages, available: localizations, development: development)
        return make(localization, resources: resources, mac: mac)
    }

    /// The language the widgets draw in now: BatteryPulse's own, from the feed, read once per
    /// burst of timeline requests and shared by every kind (``WidgetReads/feed``).
    static func current() async -> WidgetLanguageTable {
        let state = await WidgetReads.feed.value()
        let bundle = Bundle.main
        let table = chosen(
            by: state, localizations: bundle.localizations, development: bundle.developmentLocalization,
            resources: bundle.resourceURL)
        if state?.feed != nil, table.localization == nil {
            Diagnostics.widget.notice("The widget found no table for BatteryPulse's language; it draws in its own")
        }
        return table
    }
}

extension View {
    /// The words and the locale of `language` for everything below; the extension's own language
    /// changes nothing. The widgets' root views set it, so the system's own text (the time left)
    /// follows it too.
    @ViewBuilder func widgetLanguage(_ language: WidgetLanguageTable) -> some View {
        if let locale = language.locale {
            environment(\.widgetStrings, language.strings)
                .environment(\.locale, locale)
        } else {
            self
        }
    }
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
        case .chargedToLimit: "Charged to limit"
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

    /// The shorter words a one-line attention row shows when the condition's don't fit
    /// (BatteryCore's `shortKey`).
    var shortTitle: LocalizedStringResource? {
        switch self {
        case .serviceRecommended: "Service"
        case .normal, .fair, .poor, .checkBattery, .other: nil
        }
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

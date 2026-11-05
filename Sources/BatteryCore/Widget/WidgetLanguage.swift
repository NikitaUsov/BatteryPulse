import Foundation

/// The language the widgets draw in: BatteryPulse's own, which the app writes into the feed
/// (``WidgetFeed/languages``), so a language chosen for BatteryPulse alone in System Settings
/// (General → Language & Region → Applications) reaches the sandboxed widget, which runs in the
/// Mac's language otherwise. Without a feed, the widget keeps the extension's own language, as
/// before 0.7.1.
///
/// A plain function of its inputs, so Linux tests it: the widget passes its own localizations
/// (`Bundle.main.localizations`, "en" and "ru") and its development localization, and draws in
/// what this chooses, English included, from that language's own table.
public enum WidgetLanguage {
    /// The localization of `available` to draw in for `preferences`, the feed's languages: the
    /// first preference with a match, as `Bundle.preferredLocalizations(from:forPreferences:)`
    /// chooses one, matched by the same identifier ("ru"), then by a more general one ("ru-RU"
    /// draws in "ru"), then by another region's of the same language and script; a list with no
    /// match, an empty one included, gets `development`, as an app runs in its development
    /// localization when none of its languages is the user's. `nil` without a feed, which keeps
    /// the extension's own language, or with no localization to choose from.
    public static func localization(for preferences: [String]?, available: [String], development: String?) -> String? {
        guard let preferences else { return nil }
        let candidates = available.filter { !$0.isEmpty && $0 != "Base" }
        guard !candidates.isEmpty else { return nil }
        for preference in preferences {
            if let match = match(preference, in: candidates) { return match }
        }
        if let development, let match = match(development, in: candidates) { return match }
        return candidates.first
    }

    /// `localization`'s language in the Mac's locale `mac`: its region and the settings that go
    /// with it (the hour cycle, the first weekday, a region whose formats the user chose), so the
    /// numbers and times keep the region's formats, as BatteryPulse's own do when it runs in a
    /// language chosen for it alone ("ru" on a US Mac writes "5,497", as the app does).
    public static func locale(_ localization: String, mac: Locale) -> Locale {
        let language = Locale.Language.Components(identifier: localization)
        var components = Locale.Components(locale: mac)
        components.languageComponents.languageCode = language.languageCode
        components.languageComponents.script = language.script
        return Locale(components: components)
    }

    /// The localization of `available` that `preference` matches best, or `nil`.
    static func match(_ preference: String, in available: [String]) -> String? {
        let wanted = Tag(preference)
        guard !wanted.subtags.isEmpty else { return nil }
        let tags = available.map(Tag.init)
        // The same identifier, whatever its case or separator.
        if let index = tags.firstIndex(where: { $0.subtags == wanted.subtags }) { return available[index] }
        // A more general one: "zh-Hant-TW", then "zh-Hant", then "zh".
        var parent = wanted.subtags
        while parent.count > 1 {
            parent.removeLast()
            if let index = tags.firstIndex(where: { $0.subtags == parent }) { return available[index] }
        }
        // Another region's of the same language, and of the same script when both name one.
        let index = tags.firstIndex { tag in
            tag.language == wanted.language
                && (tag.script == nil || wanted.script == nil || tag.script == wanted.script)
        }
        return index.map { available[$0] }
    }

    /// A language identifier's subtags, lowercased: "pt_BR" and "pt-br" are both `["pt", "br"]`.
    struct Tag {
        var subtags: [String]

        init(_ identifier: String) {
            subtags = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
        }

        var language: String? { subtags.first }

        /// The script subtag, four letters after the language ("hant" in "zh-Hant-TW").
        var script: String? {
            guard subtags.count > 1, subtags[1].count == 4, subtags[1].allSatisfy(\.isLetter) else { return nil }
            return subtags[1]
        }
    }
}

import Foundation
import Testing

@testable import BatteryCore

/// The widgets' language (W-15): BatteryPulse's own, from the feed, matched against the widget's
/// localizations as a bundle matches its preferred localizations; the extension's own without a
/// feed.
struct WidgetLanguageTests {
    /// The widget's localizations, and its development localization.
    static let widget = ["en", "ru"]

    static func choice(_ preferences: [String]?) -> String? {
        WidgetLanguage.localization(for: preferences, available: widget, development: "en")
    }

    @Test func theFeedsLanguagesChooseTheWidgets() {
        #expect(Self.choice(["ru"]) == "ru")
        // English itself, from its own table: never the extension's own language, which on a
        // Russian Mac would be Russian.
        #expect(Self.choice(["en"]) == "en")
        #expect(Self.choice(["ru-RU", "en"]) == "ru")
        #expect(Self.choice(["en", "ru"]) == "en")
        #expect(Self.choice(["de", "en"]) == "en")
        #expect(Self.choice(["de", "ru"]) == "ru")
        // None of them, or none at all: the development localization, as the app runs in.
        #expect(Self.choice(["de"]) == "en")
        #expect(Self.choice([]) == "en")
        // No feed: the extension's own language.
        #expect(Self.choice(nil) == nil)
    }

    @Test func identifiersMatchWhateverTheirCaseOrSeparator() {
        #expect(Self.choice(["RU"]) == "ru")
        #expect(Self.choice(["ru_RU"]) == "ru")
        #expect(Self.choice(["en-GB"]) == "en")
        #expect(Self.choice(["en_US_POSIX"]) == "en")
        // What the bundle lists comes back as it lists it.
        #expect(WidgetLanguage.localization(for: ["pt-br"], available: ["en", "pt_BR"], development: "en") == "pt_BR")
    }

    /// The order a bundle matches in: the same identifier, a more general one, then another
    /// region's of the same language and script.
    @Test func aCloserMatchWinsOverAMoreGeneralOne() {
        let available = ["en", "zh-Hans", "zh-Hant", "zh-Hant-HK", "pt-PT"]
        func choice(_ preference: String) -> String? {
            WidgetLanguage.localization(for: [preference], available: available, development: "en")
        }
        #expect(choice("zh-Hant-HK") == "zh-Hant-HK")
        #expect(choice("zh-Hant-TW") == "zh-Hant")
        #expect(choice("zh-Hans-CN") == "zh-Hans")
        #expect(choice("zh-Hant-MO") == "zh-Hant")
        // Another region's of the same language.
        #expect(choice("pt-BR") == "pt-PT")
        // Never another script's.
        #expect(WidgetLanguage.localization(for: ["zh-Hant"], available: ["en", "zh-Hans"], development: "en") == "en")
    }

    @Test func withoutTheDevelopmentLocalizationTheFirstIsDrawn() {
        #expect(WidgetLanguage.localization(for: ["de"], available: ["ru", "en"], development: nil) == "ru")
        #expect(WidgetLanguage.localization(for: ["de"], available: ["ru", "en"], development: "fr") == "ru")
        // "Base" holds no words of its own.
        #expect(WidgetLanguage.localization(for: ["de"], available: ["Base", "ru"], development: "en") == "ru")
        #expect(WidgetLanguage.localization(for: ["ru"], available: [], development: "en") == nil)
        #expect(WidgetLanguage.localization(for: ["ru"], available: ["Base", ""], development: "en") == nil)
    }

    /// The language changes and the region stays, with the formats that go with it, as the app's
    /// own numbers do in a language chosen for it alone.
    @Test func theLocaleKeepsTheMacsRegion() {
        let russianOnAUSMac = WidgetLanguage.locale("ru", mac: Locale(identifier: "en_US"))
        #expect(russianOnAUSMac.language.languageCode?.identifier == "ru")
        #expect(russianOnAUSMac.region?.identifier == "US")
        #expect(5_497.formatted(.number.locale(russianOnAUSMac)) == "5,497")

        let englishOnARussianMac = WidgetLanguage.locale("en", mac: Locale(identifier: "ru_RU"))
        #expect(englishOnARussianMac.language.languageCode?.identifier == "en")
        #expect(englishOnARussianMac.region?.identifier == "RU")
        #expect(
            5_497.formatted(.number.locale(englishOnARussianMac))
                == 5_497.formatted(.number.locale(Locale(identifier: "ru_RU"))))

        // The hour cycle the user chose, and a region whose formats the user chose, stay.
        let hours = WidgetLanguage.locale("ru", mac: Locale(identifier: "en_US@hours=h23"))
        #expect(hours.hourCycle == .zeroToTwentyThree)
        let regionFormats = WidgetLanguage.locale("en", mac: Locale(identifier: "de_DE@rg=chzzzz"))
        #expect(regionFormats.language.languageCode?.identifier == "en")
        #expect(regionFormats.region?.identifier == "CH")

        // A script goes with the language; the Mac's script doesn't stay.
        let traditional = WidgetLanguage.locale("zh-Hant", mac: Locale(identifier: "sr_Latn_RS"))
        #expect(traditional.language.languageCode?.identifier == "zh")
        #expect(traditional.language.script?.identifier == "Hant")
        #expect(traditional.region?.identifier == "RS")
        #expect(
            WidgetLanguage.locale("ru", mac: Locale(identifier: "sr_Latn_RS")).language.script?.identifier != "Latn")
    }

    /// The widget's percentages keep no space before the sign in the language it draws in.
    @Test func theLocalesPercentHasNoSpaceBeforeTheSign() {
        let formatter = BatteryFormatter(locale: WidgetLanguage.locale("ru", mac: Locale(identifier: "en_US")))
        let percent = formatter.percent(99.5, fractionDigits: 1)
        #expect(percent.allSatisfy { !$0.isWhitespace }, "\(percent)")
    }
}

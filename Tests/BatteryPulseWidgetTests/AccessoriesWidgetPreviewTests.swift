#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import Testing
import WidgetKit

@testable import BatteryPulseWidget

/// Renders the Accessories widget into PNGs for the second look (plan-0.7.0 §6.1b), beside the
/// Battery widget's (``WidgetPreviewTests``, whose frame, languages, rendering modes and sheets
/// these reuse): every family the kind declares, in English and Russian.
///
/// - `accessories-<family>-<scene>[-<mode>][-dark][-ru].png` are the single widgets: full colour,
///   light and English unless the name says otherwise;
/// - `sheet-accessories[-ru].png` holds every scene in small, medium and large, and
///   `sheet-accessories-modes-<family>[-ru].png` every rendering mode in light and dark.
///
/// The accessories are Demo Mode's, and made-up ones with product names, never anyone's own.
@MainActor
struct AccessoriesWidgetPreviewTests {
    typealias Language = WidgetPreviewTests.Language
    typealias Look = WidgetPreviewTests.Look

    static let families: [WidgetSize] = [.small, .medium, .large]

    /// What a picture shows: the accessories a read found, a configuration and the timeline's
    /// moment.
    struct Scene: Sendable {
        var name: String
        var title: String
        var accessories: [AccessoryBattery]?
        var configuration = AccessoriesWidgetConfiguration()
        /// The reading is 50 minutes old: the timeline's stale entry.
        var stale = false
    }

    /// One accessory with one battery, or with `parts`.
    static func accessory(
        _ name: String, _ kind: AccessoryKind, _ percent: Int, charging: Bool = false, onPower: Bool = false,
        offline: Bool = false, parts: [AccessoryPart]? = nil
    ) -> AccessoryBattery {
        AccessoryBattery(
            id: "preview-\(name)-\(kind)", name: name, kind: kind, transport: .bluetooth,
            parts: parts ?? [
                AccessoryPart(
                    role: .single, percent: percent, isCharging: charging, isOnExternalPower: onPower,
                    isOffline: offline)
            ])
    }

    /// Demo Mode's: a keyboard, a mouse at 18 % and earbuds whose case charges.
    static let demo = AccessoryReading(sources: DemoAccessories.sources).accessories

    /// More than large lists: the lowest critical with a long name, earbuds, one that charges, a
    /// headset, one full on its cable, one out of reach that reports no name, and two more.
    static let many: [AccessoryBattery] =
        demo + [
            accessory("Magic Keyboard with Touch ID and Numeric Keypad", .keyboard, 8),
            accessory("Magic Trackpad", .trackpad, 54, charging: true),
            accessory("AirPods Max", .headphones, 45),
            accessory("", .gameController, 30, offline: true),
            accessory("Magic Mouse", .mouse, 100, onPower: true),
            accessory("Studio Speaker", .speaker, 88),
        ]

    static let all = Scene(name: "all", title: "All (the default)", accessories: demo)
    static let lowest = Scene(
        name: "lowest-only", title: "Lowest only", accessories: demo,
        configuration: AccessoriesWidgetConfiguration(mode: .lowest))
    static let crowded = Scene(name: "many", title: "Nine accessories", accessories: many)
    static let hide = Scene(
        name: "hide-fully-charged", title: "Hide fully charged", accessories: many,
        configuration: AccessoriesWidgetConfiguration(hidesFullyCharged: true))
    static let earbuds = Scene(
        name: "earbuds-lowest", title: "Lowest only: earbuds", accessories: demo.filter(\.hasParts),
        configuration: AccessoriesWidgetConfiguration(mode: .lowest))
    static let charging = Scene(
        name: "charging", title: "Charging", accessories: [accessory("Magic Trackpad", .trackpad, 54, charging: true)])
    static let critical = Scene(
        name: "critical", title: "Critical", accessories: [accessory("Magic Mouse", .mouse, 8)])
    static let unnamed = Scene(
        name: "out-of-reach", title: "Out of reach, no name",
        accessories: [accessory("", .gameController, 30, offline: true)])
    static let old = Scene(name: "reading-old", title: "Reading 50 minutes old", accessories: demo, stale: true)
    static let allFull = Scene(
        name: "all-fully-charged", title: "Hide fully charged, all full",
        accessories: [accessory("Magic Keyboard", .keyboard, 100, onPower: true)],
        configuration: AccessoriesWidgetConfiguration(hidesFullyCharged: true))
    static let none = Scene(name: "none-connected", title: "None connected", accessories: [])

    static let scenes: [Scene] = [all, lowest, crowded, hide, earbuds, charging, critical, unnamed, old, allFull, none]

    /// The scenes drawn in every rendering mode and appearance.
    static let modeScenes: [Scene] = [all, lowest, crowded, none]

    /// The widget as it draws `scene` in `size`, `look` and `language`, in its place.
    static func widget(_ scene: Scene, _ size: WidgetSize, _ look: Look, _ language: Language) -> some View {
        let date = WidgetPreviewTests.date
        let moment = WidgetTimelinePlan.Entry(date: date, showsEstimate: false, isStale: scene.stale)
        let entry = AccessoriesEntry(
            accessories: scene.accessories, readAt: scene.stale ? date.addingTimeInterval(-50 * 60) : date,
            moment: moment, configuration: scene.configuration)
        return WidgetPreviewTests.framed(
            AccessoriesWidgetView(
                entry: entry, size: size, formatter: language.formatter, timeZone: WidgetPreviewTests.timeZone),
            size, look, language)
    }

    static func picture(
        _ scene: Scene, _ size: WidgetSize, _ language: Language, look: Look = .standard, caption: String? = nil
    ) -> WidgetPreviewTests.Picture {
        WidgetPreviewTests.Picture(
            caption: caption ?? "\(WidgetPreviewTests.title(size)) · \(scene.title)",
            width: WidgetPreviewTests.points(size).width, view: AnyView(widget(scene, size, look, language)))
    }

    static func fileName(_ scene: Scene, _ size: WidgetSize, _ look: Look, _ language: Language) -> String {
        "accessories-\(WidgetPreviewTests.fileName(size))-\(scene.name)\(look.name)\(language.suffix)"
    }

    /// Every scene in every family, in full colour and light.
    @Test(arguments: Language.allCases)
    func rendersEveryFamilyAndScene(_ language: Language) throws {
        guard WidgetPreviewTests.languages.contains(language) else { return }
        for size in Self.families {
            for scene in Self.scenes {
                try WidgetPreviewTests.write(
                    Self.widget(scene, size, .standard, language), Self.fileName(scene, size, .standard, language))
            }
        }
    }

    /// A few scenes in every other rendering mode and appearance.
    @Test(arguments: Language.allCases)
    func rendersEveryModeAndAppearance(_ language: Language) throws {
        guard WidgetPreviewTests.languages.contains(language) else { return }
        for size in Self.families {
            for scene in Self.modeScenes {
                for look in Look.all where !look.isStandard {
                    try WidgetPreviewTests.write(
                        Self.widget(scene, size, look, language), Self.fileName(scene, size, look, language))
                }
            }
        }
    }

    /// The second look's sheets: every scene in small, medium and large, and every rendering mode
    /// in light and dark per family.
    @Test(arguments: Language.allCases)
    func rendersTheSecondLooksSheets(_ language: Language) throws {
        guard WidgetPreviewTests.languages.contains(language) else { return }
        let rows = Self.scenes.map { scene in Self.families.map { Self.picture(scene, $0, language) } }
        try WidgetPreviewTests.write(
            WidgetPreviewTests.sheet("The Accessories widget: small, medium and large — \(language.name)", rows),
            "sheet-accessories\(language.suffix)")
        for size in Self.families {
            let rows = Look.all.map { look in
                Self.modeScenes.map {
                    Self.picture($0, size, language, look: look, caption: "\(look.title) · \($0.title)")
                }
            }
            let family = WidgetPreviewTests.title(size).lowercased()
            try WidgetPreviewTests.write(
                WidgetPreviewTests.sheet(
                    "The Accessories widget's rendering modes, \(family); accented and vibrant approximate — "
                        + language.name, rows),
                "sheet-accessories-modes-\(WidgetPreviewTests.fileName(size))\(language.suffix)")
        }
    }
}
#endif

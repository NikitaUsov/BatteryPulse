#if os(macOS)
import Foundation
import Testing

@testable import BatteryCore
@testable import BatteryPulseWidget

/// The words the widget shows are the keys VoiceOver's labels use (BatteryCore's
/// `WidgetAccessibility`), so a label never says something the widget doesn't.
struct WidgetWordTests {
    @Test func fieldLabels() {
        for field in BatteryWidgetField.allCases {
            #expect(field.label.key == field.labelKey, "\(field)")
        }
    }

    @Test func stateWords() {
        for word in WidgetStateWord.allCases {
            #expect(WidgetPhrase.key(word.title.key) == word.phrase, "\(word)")
        }
    }

    @Test func conditions() {
        let conditions: [WidgetCondition] = [.normal, .fair, .poor, .checkBattery, .serviceRecommended]
        for condition in conditions {
            #expect(WidgetPhrase.key(condition.title.key) == condition.phrase, "\(condition)")
        }
        #expect(WidgetCondition.other("Permanent Battery Failure").phrase == .verbatim("Permanent Battery Failure"))
    }

    /// The Accessories widget's words for an accessory without a name and for a part's state.
    @Test func accessoryWords() {
        for kind in AccessoryKind.allCases {
            #expect(kind.title.key == kind.titleKey, "\(kind)")
        }
        for status in AccessoryWidgetStatus.allCases {
            #expect(WidgetPhrase.key(status.title.key) == status.phrase, "\(status)")
        }
    }

    @Test func thermalStates() {
        for state in ThermalState.allCases {
            #expect(WidgetPhrase.key(state.title.key) == state.phrase, "\(state)")
        }
    }
}
#endif

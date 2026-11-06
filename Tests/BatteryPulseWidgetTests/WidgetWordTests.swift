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
            #expect(field.shortLabel?.key == field.shortLabelKey, "\(field)")
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
            #expect(condition.shortTitle?.key == condition.shortKey, "\(condition)")
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
            #expect(status.shortTitle?.key == status.shortKey, "\(status)")
        }
    }

    /// The History widget's and the large Battery widget's chart words: the series' names, the
    /// spans and values VoiceOver reads with a chart, the figures' names and the messages.
    @Test func historyWords() {
        for series in HistoryWidgetSeries.allCases {
            #expect(series.title.key == series.titleKey, "\(series)")
        }
        for span in WidgetChartSummary.Span.allCases {
            #expect(span.title.key == span.titleKey, "\(span)")
        }
        let summary = WidgetChartSummary(series: .charge, span: .hours24, lowest: "1", highest: "2", latest: "3")
        guard case .phrases(let phrases) = summary.spokenLabel, case .key(let values, _)? = phrases.last else {
            Issue.record("\(summary.spokenLabel)")
            return
        }
        #expect(WidgetChartSummary.values.key == values)
        for kind in HistoryWidgetStatistic.Kind.allCases {
            #expect(kind.label.key == kind.labelKey, "\(kind)")
        }
        for reason in HistoryWidgetEmptyReason.allCases {
            #expect(reason.message.key == reason.messageKey, "\(reason)")
        }
    }

    @Test func thermalStates() {
        for state in ThermalState.allCases {
            #expect(WidgetPhrase.key(state.title.key) == state.phrase, "\(state)")
        }
    }
}
#endif

import Foundation

// The summary at the top of Health, which answers "is my battery OK?" with what macOS itself
// reports, label beside value, and no grade of BatteryPulse's own: the battery's condition in
// macOS's word ("Normal" when it reports none), its maximum capacity as System Settings → Battery
// shows it (capped at 100 %), and its cycles out of the rated count ("52 of 1,000"). Clear's warning
// badge names what warns in the same terms: the condition macOS reports, or, when only the capacity
// is low, that fact; never "Service Recommended", macOS's word for its own judgement, unless macOS
// says it.
//
// The words are catalog keys, keyed by their English text, whose `%@` placeholders take
// pre-formatted values, as the widget's (`WidgetAccessibility`) and VoiceOver's (`AccessibilityText`)
// are: the app localizes them, and the tests read them in English and in the catalog's Russian.

/// Health's summary of the Mac battery: its rows, and the words of Clear's warning badge.
public enum HealthSummary {
    /// One row of the summary: a label and its value.
    public struct Row: Sendable {
        /// The label, a catalog key: "Condition", "Maximum capacity" or "Cycle count".
        public let labelKey: String
        /// A number formatted for the language, or catalog keys ("Normal", "%@ of %@").
        let value: WidgetPhrase

        /// The value in one language, its keys through `localize`: "Normal", "100%", "52 of 1,000".
        public func valueText(_ localize: (String) -> String) -> String {
            value.text(localize)
        }
    }

    /// Every catalog key the rows and the badge can use, for the catalog's check: the app reads them
    /// through BatteryCore, so its sources needn't name them.
    public static let catalogKeys: Set<String> = [
        "Condition", "Maximum capacity", "Cycle count", "Normal", "Fair", "Poor", "Check Battery",
        "Service Recommended", "%@ of %@", "Maximum capacity below %@",
    ]

    /// The summary of `s`, in its order: Condition, Maximum capacity, Cycle count. The condition is
    /// the one macOS reports, "Normal" without one or with an empty one (``WidgetCondition``); the
    /// capacity (``BatterySnapshot/healthPercent``) and the cycles show only when the battery
    /// reports them, the cycles out of the rated count when it reports one.
    public static func rows(for s: BatterySnapshot, formatter f: BatteryFormatter) -> [Row] {
        var rows = [Row(labelKey: "Condition", value: WidgetCondition(s.healthCondition).phrase)]
        if let health = s.healthPercent {
            rows.append(Row(labelKey: "Maximum capacity", value: .verbatim(f.percent(health))))
        }
        if let cycles = s.cycleCount {
            let count = WidgetPhrase.verbatim(cycles.formatted(.number.locale(f.locale)))
            let value =
                BatteryPresentation.ratedCycles(s.designCycleCount).map {
                    WidgetPhrase.key("%@ of %@", [count, .verbatim($0.formatted(.number.locale(f.locale)))])
                } ?? count
            rows.append(Row(labelKey: "Cycle count", value: value))
        }
        return rows
    }

    /// The words on Clear's warning badge for the health of `s`, in one language, its keys through
    /// `localize`; `nil` while ``BatteryPresentation/healthTier(for:)`` is normal, when nothing warns.
    public static func warningText(
        for s: BatterySnapshot, formatter f: BatteryFormatter, _ localize: (String) -> String
    ) -> String? {
        warning(for: s, formatter: f)?.text(localize)
    }

    /// The badge's words: the condition macOS reports when it isn't Normal; else the capacity under
    /// ``BatteryPresentation/capacityWarningPercent``, the only other reason the tier warns.
    static func warning(for s: BatterySnapshot, formatter f: BatteryFormatter) -> WidgetPhrase? {
        guard BatteryPresentation.healthTier(for: s) != .normal else { return nil }
        let condition = WidgetCondition(s.healthCondition)
        guard condition == .normal else { return condition.phrase }
        return .key(
            "Maximum capacity below %@", [.verbatim(f.percent(BatteryPresentation.capacityWarningPercent))])
    }
}

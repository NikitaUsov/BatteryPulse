import Foundation
import Testing

@testable import BatteryCore

/// The Battery widget's two details from the feed, Custom only: the average drain and the time on
/// battery.
struct WidgetFeedDetailTests {
    /// "%@ per hour" and the time since the unplug, each "—" without what it needs.
    @Test func theFeedDetails() throws {
        var onBattery = WidgetRowTests.full
        onBattery.chargeState = .discharging
        onBattery.isExternalPowerConnected = false
        let custom = BatteryWidgetConfiguration(layout: .custom, details: [.averageDrain, .timeOnBattery])
        let sample = WidgetFeed.sample(at: onBattery.timestamp)
        func details(_ snapshot: BatterySnapshot, _ feed: WidgetFeed?) throws -> [WidgetDetail] {
            try WidgetChartTests.battery(.medium, custom, snapshot, feed: feed).details
        }
        func values(_ snapshot: BatterySnapshot, _ feed: WidgetFeed?) throws -> [WidgetValue] {
            try details(snapshot, feed).compactMap { if case .row(let row) = $0 { row.value } else { nil } }
        }
        let since = try #require(sample.onBatterySince)
        #expect(try values(onBattery, sample) == [.perHour("6.4%"), .since(since)])
        #expect(try values(onBattery, nil) == [.text("—"), .text("—")])
        // On the adapter, no time on battery.
        #expect(try values(WidgetRowTests.full, sample) == [.perHour("6.4%"), .text("—")])
        // VoiceOver: the label, then the value; the time is the system's own text.
        #expect(
            try details(onBattery, sample).map(\.spokenLabel) == [
                .phrases([.key("Average drain"), .key("%@ per hour", [.verbatim("6.4%")])]),
                .counting(label: "Time on battery", since: since),
            ])
        #expect(WidgetSpokenLabel.counting(label: "Time on battery", since: since).text { $0 } == nil)
        #expect(WidgetSpokenLabel.counting(label: "Time on battery", since: since).keys == ["Time on battery"])
    }

    /// Automatic never shows them, in any size, so Automatic's meaning stays as 0.7.0 shipped it.
    @Test func theyAreCustomOnly() {
        for size in WidgetSize.allCases {
            let automatic = WidgetLayoutPlan.automatic(size)
            #expect(!automatic.contains(.averageDrain) && !automatic.contains(.timeOnBattery), "\(size)")
        }
    }
}

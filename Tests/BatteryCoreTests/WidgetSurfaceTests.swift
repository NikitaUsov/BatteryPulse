import Foundation
import Testing

@testable import BatteryCore

/// The widget's frozen surfaces: macOS stores placed widgets and their configuration under these
/// strings, so a release can never rename or remove one (it can only add). A change here needs a
/// reason in the commit, and before a release, D1's identifier check.
struct WidgetSurfaceTests {
    @Test func kindStrings() {
        #expect(WidgetKindID.battery.rawValue == BatteryWidgetKind.battery)
        #expect(
            WidgetKindID.allCases.map(\.rawValue) == [
                "io.github.nikitausov.BatteryPulse.battery", "io.github.nikitausov.BatteryPulse.accessories",
            ])
    }

    @Test func sizes() {
        #expect(
            WidgetSize.allCases.map(\.rawValue) == ["small", "medium", "large", "extraLarge", "extraLargePortrait"])
    }

    @Test func choiceRawValues() {
        #expect(
            BatteryWidgetField.allCases.map(\.rawValue) == [
                "state", "time", "maximumCapacity", "condition", "cycleCount", "temperature", "adapter",
                "systemLoad", "batteryPower", "adapterInput", "lowPowerMode", "remainingCapacity", "cycleLifeUsed",
                "cellBalance", "voltage",
            ])
        #expect(
            BatteryWidgetMain.allCases.map(\.rawValue) == ["charge", "maximumCapacity", "temperature", "batteryPower"])
        #expect(BatteryWidgetVisual.allCases.map(\.rawValue) == ["symbol", "ring", "drawnBattery"])
        #expect(WidgetLayoutMode.allCases.map(\.rawValue) == ["automatic", "custom"])
        #expect(WidgetStatusLine.allCases.map(\.rawValue) == ["state", "time"])
        #expect(WidgetTimeStyle.allCases.map(\.rawValue) == ["clockTime", "timeLeft"])
        #expect(WidgetColorStyle.allCases.map(\.rawValue) == ["levelColors", "monochrome"])
        #expect(WidgetUpdateTimeStyle.allCases.map(\.rawValue) == ["whenOld", "always"])
        #expect(AccessoryWidgetMode.allCases.map(\.rawValue) == ["all", "lowest"])
    }
}

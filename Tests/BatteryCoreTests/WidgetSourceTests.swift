import Foundation
import Testing

@testable import BatteryCore

/// What the widget's sources must say that only CI compiles: Linux reads them as text
/// (``SourceScanner``).
struct WidgetSourceTests {
    /// Each unit symbol of a `BatteryFormatter` built in `path`, as `label: key`, from the
    /// declaration that starts with `declaration` to its closing parentheses.
    static func unitSymbolKeys(in path: String, declaration: String) throws -> [String] {
        let text = try SourceScanner.file(path).text
        let start = try #require(text.range(of: declaration), "\(path): no \(declaration)")
        let end = try #require(text.range(of: ")))", range: start.upperBound..<text.endIndex), "\(path): no end")
        return text[start.upperBound..<end.upperBound].matches(of: #/(\w+):\s*String\(localized:\s*"([^"]*)"/#)
            .map { "\($0.output.1): \($0.output.2)" }
    }

    /// The widget's numbers use the app's unit symbols, the same six catalog keys (L10N-05).
    @Test func theWidgetsUnitSymbolsAreTheApps() throws {
        let app = try Self.unitSymbolKeys(
            in: "BatteryPulseApp/App/Localized.swift", declaration: "static let app = BatteryFormatter(")
        let widget = try Self.unitSymbolKeys(
            in: "BatteryPulseWidget/WidgetFormatter.swift", declaration: "static let widget = BatteryFormatter(")
        #expect(app.count == 6)
        #expect(widget == app)
    }
}

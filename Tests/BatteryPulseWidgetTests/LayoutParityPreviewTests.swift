#if os(macOS)
import BatteryCore
import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import BatteryPulseWidget

/// Look 3 (plan-0.7.1 §6.1): every widget and state 0.7.1 adds, English beside Russian, with where
/// each picture's lines lie, so the two can be seen to lay out alike, as 0.7's parity work measured
/// its pictures. The scenes are Look 1's and Look 2's (``HistoryWidgetPreviewTests``,
/// ``DevicesWidgetPreviewTests``), in full colour and light, in each family the kind declares.
///
/// - `sheet-look3-<n>-<subject>.png` are its sheets: 1 the History widget, 2 the large Battery
///   widget's chart and the two new details, 3 the iPhone & iPad widget. Each English picture has
///   its Russian one beside it, whose caption says how their lines compare.
/// - `look3-measurements.md` lists every pair with its lines in points, and the log has a line per
///   pair.
///
/// A line here is a band of pixel rows that hold anything but the widget's fill: text, a symbol, a
/// chart's stroke. A pair lays out alike when both pictures have as many bands, each band's top
/// within ``tolerance`` of its pair's and its bottom within ``descent``: room for the two scripts'
/// glyphs and for the Russian decimal comma, which reaches below the line where the English point
/// doesn't (0.7.1's first sheets measured 2.5 points under a value's row, 6 under a 34-point main
/// value), but not for a line more, a moved line or a value drawn smaller. Nothing here fails on
/// what it measures; the maintainer decides on the pictures.
@MainActor
struct LayoutParityPreviewTests {
    typealias Language = WidgetPreviewTests.Language
    typealias Picture = WidgetPreviewTests.Picture

    /// How far a band's top may lie from its pair's, in points.
    nonisolated static let tolerance = 2.0
    /// How far a band's bottom may lie from its pair's, in points: a comma's or a descender's depth
    /// under the largest value, less than a caption line's height, so a line more still shows.
    nonisolated static let descent = 7.0
    /// How far a channel must differ from the widget's fill, of 255, for a pixel to count as drawn:
    /// above a chart's shading, below any text's.
    nonisolated static let threshold = 40

    /// A widget in one scene and size, drawn in either language.
    struct Pair {
        var widget: String
        var title: String
        var size: WidgetSize
        var draw: @MainActor (Language) -> AnyView
    }

    static func history(_ scene: HistoryWidgetPreviewTests.Scene, _ size: WidgetSize) -> Pair {
        Pair(widget: "History", title: scene.title, size: size) {
            AnyView(HistoryWidgetPreviewTests.widget(scene, size, .standard, $0))
        }
    }

    static func battery(_ scene: WidgetPreviewTests.Scene, _ size: WidgetSize) -> Pair {
        Pair(widget: "Battery", title: scene.title, size: size) {
            AnyView(WidgetPreviewTests.widget(scene, size, .standard, $0))
        }
    }

    static func devices(_ scene: DevicesWidgetPreviewTests.Scene, _ size: WidgetSize) -> Pair {
        Pair(widget: "iPhone & iPad", title: scene.title, size: size) {
            AnyView(DevicesWidgetPreviewTests.widget(scene, size, .standard, $0))
        }
    }

    /// Look 3's sheets, numbered as Look 1's and Look 2's widgets are, with the pairs a row holds.
    static var sheets: [(name: String, heading: String, perRow: Int, pairs: [Pair])] {
        let h = HistoryWidgetPreviewTests.self
        let d = DevicesWidgetPreviewTests.self
        let historyScenes: [HistoryWidgetPreviewTests.Scene] = h.options + h.states
        let charts: [WidgetPreviewTests.Scene] = [
            h.chartOnBattery, h.chartCharging, h.rowsOnBattery, h.rowsCharging, h.chartCustom, h.chartOld, h.chartOff,
            h.chartNothing, h.chartNoFeed,
        ]
        let details: [WidgetPreviewTests.Scene] = [h.detailsOnBattery, h.detailsCharging, h.detailsNoFeed]
        let detailPairs: [Pair] = details.flatMap { scene in WidgetPreviewTests.families.map { battery(scene, $0) } }
        let choices: [DevicesWidgetPreviewTests.Scene] = d.choices + [d.notChosen, d.unnamed, d.yesterday]
        let deviceScenes: [DevicesWidgetPreviewTests.Scene] = choices + d.states
        return [
            (
                "1-history-medium", "1. The History widget, medium: every content option and state", 2,
                historyScenes.map { history($0, .medium) }
            ),
            (
                "1-history-large-options", "1. The History widget, large: every content option", 2,
                h.options.map { history($0, .large) }
            ),
            (
                "1-history-large-states", "1. The History widget, large: the states", 2,
                h.states.map { history($0, .large) }
            ),
            (
                "2-battery-large-chart", "2. The large Battery widget: the History chart, the eight rows, the states",
                2, charts.map { battery($0, .large) }
            ),
            (
                "2-battery-new-details", "2. The two new details, Average drain and Time on battery, in Custom", 3,
                detailPairs
            ),
            (
                "3-devices-small", "3. The iPhone & iPad widget, small: every Show choice and state", 3,
                deviceScenes.map { devices($0, .small) }
            ),
            (
                "3-devices-medium", "3. The iPhone & iPad widget, medium: every Show choice and state", 2,
                deviceScenes.map { devices($0, .medium) }
            ),
            (
                "3-devices-large-choices", "3. The iPhone & iPad widget, large: every Show choice", 2,
                choices.map { devices($0, .large) }
            ),
            (
                "3-devices-large-states", "3. The iPhone & iPad widget, large: the states", 2,
                d.states.map { devices($0, .large) }
            ),
        ]
    }

    // MARK: Measuring

    /// A band of pixel rows with something drawn in them: its top and bottom in points from the
    /// picture's top, and its leftmost and rightmost drawn pixel in points from its left.
    struct Band: Equatable {
        var top: Double
        var bottom: Double
        var left: Double
        var right: Double
    }

    /// The bands of `image`, a picture at twice its size in points, top to bottom; `nil` when its
    /// pixels can't be read.
    nonisolated static func bands(_ image: CGImage) -> [Band]? {
        let width = image.width
        let height = image.height
        guard width > 32, height > 32, let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Redrawn in one known format: premultiplied RGBA, 8 bits a channel, the top row first.
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.makeImage(), let data = pixels.dataProvider?.data else { return nil }
        let bytes = [UInt8](data as Data)
        let stride = pixels.bytesPerRow
        guard stride >= width * 4, bytes.count >= stride * height else { return nil }
        // The widget's fill, 8 points in from its top left corner: in its margin, inside the
        // corner's curve.
        let probe = 16 * stride + 16 * 4
        let fill = (Int(bytes[probe]), Int(bytes[probe + 1]), Int(bytes[probe + 2]))
        var bands: [Band] = []
        var open: (top: Int, left: Int, right: Int)?
        for y in 0..<height {
            var left = Int.max
            var right = -1
            for x in 0..<width {
                let pixel = y * stride + x * 4
                // Only opaque pixels: outside the corners' curves the picture is clear.
                guard bytes[pixel + 3] > 200 else { continue }
                let difference = max(
                    abs(Int(bytes[pixel]) - fill.0), abs(Int(bytes[pixel + 1]) - fill.1),
                    abs(Int(bytes[pixel + 2]) - fill.2))
                if difference > threshold {
                    left = min(left, x)
                    right = max(right, x)
                }
            }
            if right >= 0, let band = open {
                open = (top: band.top, left: min(band.left, left), right: max(band.right, right))
            } else if right >= 0 {
                open = (top: y, left: left, right: right)
            } else if let band = open {
                bands.append(Band(band, bottom: y))
                open = nil
            }
        }
        if let band = open {
            bands.append(Band(band, bottom: height))
        }
        return bands
    }

    /// How a Russian picture's bands compare with its English pair's.
    struct Comparison {
        var english: [Band]
        var russian: [Band]

        /// The largest distance between a band's top and its pair's, in points; `nil` when the two
        /// have a different number of bands.
        var topShift: Double? {
            guard english.count == russian.count else { return nil }
            return zip(english, russian).map { abs($0.top - $1.top) }.max() ?? 0
        }

        /// The largest distance between a band's bottom and its pair's, in points; `nil` when the
        /// two have a different number of bands.
        var bottomShift: Double? {
            guard english.count == russian.count else { return nil }
            return zip(english, russian).map { abs($0.bottom - $1.bottom) }.max() ?? 0
        }

        var isAlike: Bool {
            guard let top = topShift, let bottom = bottomShift else { return false }
            return top <= LayoutParityPreviewTests.tolerance && bottom <= LayoutParityPreviewTests.descent
        }

        var summary: String {
            guard let top = topShift, let bottom = bottomShift else {
                return "differs: \(english.count) lines in English, \(russian.count) in Russian"
            }
            let p = LayoutParityPreviewTests.points
            return
                "\(isAlike ? "alike" : "differs"): \(english.count) lines, tops within \(p(top)) pt, bottoms within \(p(bottom)) pt"
        }
    }

    /// `value` with one decimal, as the measurements list it.
    nonisolated static func points(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
    }

    /// `bands` as "top–bottom" spans in points.
    nonisolated static func spans(_ bands: [Band]) -> String {
        bands.map { "\(points($0.top))–\(points($0.bottom))" }.joined(separator: ", ")
    }

    // MARK: The sheets

    /// Look 3's sheets, its measurements and a log line a pair.
    @Test func rendersLookThreesSheets() throws {
        guard WidgetPreviewTests.russian != nil else { return }
        var report: [String] = [
            "# Look 3: layout parity, English beside Russian",
            "",
            "Each line is a band of pixel rows with something drawn in it, in points from the widget's top.",
            "A pair is alike with as many lines in both languages, each top within "
                + "\(Self.points(Self.tolerance)) pt of its pair's and each bottom within \(Self.points(Self.descent)) pt "
                + "(the Russian decimal comma reaches below the line).",
            "",
            "| Sheet | Widget | Size | Scene | Lines | Top shift (pt) | Bottom shift (pt) | Verdict |",
            "|---|---|---|---|---|---|---|---|",
        ]
        var details: [String] = ["", "## Every pair's lines", ""]
        var alike = 0
        var total = 0
        for sheet in Self.sheets {
            var rows: [[Picture]] = []
            var row: [Picture] = []
            for pair in sheet.pairs {
                let family = WidgetPreviewTests.title(pair.size)
                let name = "look3-\(sheet.name)-\(total)"
                let english = try WidgetPreviewTests.render(pair.draw(.english), name)
                let russian = try WidgetPreviewTests.render(pair.draw(.russian), "\(name)-ru")
                let englishBands = try #require(Self.bands(english), "\(name): its pixels can't be read")
                let russianBands = try #require(Self.bands(russian), "\(name)-ru: its pixels can't be read")
                let comparison = Comparison(english: englishBands, russian: russianBands)
                total += 1
                if comparison.isAlike { alike += 1 }
                let lines =
                    comparison.english.count == comparison.russian.count
                    ? "\(comparison.english.count)" : "\(comparison.english.count) / \(comparison.russian.count)"
                report.append(
                    "| \(sheet.name) | \(pair.widget) | \(family) | \(pair.title) | \(lines) | "
                        + "\(comparison.topShift.map(Self.points) ?? "—") | \(comparison.bottomShift.map(Self.points) ?? "—") | "
                        + "\(comparison.isAlike ? "alike" : "**differs**") |")
                details.append("- \(pair.widget), \(family), \(pair.title)")
                details.append("  - English: \(Self.spans(comparison.english))")
                details.append("  - Russian: \(Self.spans(comparison.russian))")
                print("Look 3, \(pair.widget), \(family), \(pair.title): \(comparison.summary)")
                let width = WidgetPreviewTests.points(pair.size).width
                row.append(
                    Picture(
                        caption: "\(family) · \(pair.title) — English", width: width,
                        view: AnyView(Image(decorative: english, scale: 2))))
                row.append(
                    Picture(
                        caption: "Russian — \(comparison.summary)", width: width,
                        view: AnyView(Image(decorative: russian, scale: 2))))
                if row.count == sheet.perRow * 2 {
                    rows.append(row)
                    row = []
                }
            }
            if !row.isEmpty { rows.append(row) }
            try WidgetPreviewTests.write(
                WidgetPreviewTests.sheet("\(sheet.heading): English, then Russian", rows), "sheet-look3-\(sheet.name)")
        }
        report.insert("\(alike) of \(total) pairs alike.", at: 2)
        report.insert("", at: 3)
        print("Look 3: \(alike) of \(total) pairs alike")
        try FileManager.default.createDirectory(at: WidgetPreviewTests.output, withIntermediateDirectories: true)
        try (report + details + [""]).joined(separator: "\n").write(
            to: WidgetPreviewTests.output.appendingPathComponent("look3-measurements.md"), atomically: true,
            encoding: .utf8)
    }

    /// The scanner's bands are pinned on a drawn picture: two bars of text-like height, one under the
    /// other, read back as two bands where they were drawn.
    @Test func bandsAreWhereTheyWereDrawn() throws {
        let view = ZStack(alignment: .topLeading) {
            Color(white: 0.95)
            Rectangle().fill(Color.black).frame(width: 40, height: 10).offset(x: 20, y: 20)
            Rectangle().fill(Color.black).frame(width: 60, height: 12).offset(x: 30, y: 50)
        }
        .frame(width: 120, height: 100)
        let image = try WidgetPreviewTests.render(view, "look3-bands-self-test")
        let bands = try #require(Self.bands(image))
        try #require(bands.count == 2)
        #expect(bands[0] == Band(top: 20, bottom: 30, left: 20, right: 60))
        #expect(bands[1] == Band(top: 50, bottom: 62, left: 30, right: 90))
    }
}

extension LayoutParityPreviewTests.Band {
    /// A band from `open`'s first row, in pixels at twice the points, up to the row `bottom`.
    init(_ open: (top: Int, left: Int, right: Int), bottom: Int) {
        self.init(
            top: Double(open.top) / 2, bottom: Double(bottom) / 2, left: Double(open.left) / 2,
            right: Double(open.right + 1) / 2)
    }
}
#endif

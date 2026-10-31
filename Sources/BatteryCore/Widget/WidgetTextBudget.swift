/// How much text each place of the widget holds at full size, so a long translation is caught on
/// Linux rather than seen shrunk, wrapped or cut off on a Mac, where a Russian picture must lay
/// out as its English pair does: the same lines, nothing shrunk or cut. Places are in points,
/// measured in CI's previews of 0.7 (2x pictures). A text's width is the sum of its characters'
/// advances at the caption size, 10 points [estimate: an open-source sans-serif's advances, scaled
/// to the widths of CI's pictures, which they match within about 1.5 %], and a text fits a place
/// with ``margin`` to spare.
///
/// - The main value is the one place that may shrink: the 34-point number, down to
///   ``mainScaleFactor``, counted in characters (the rounded digits aren't in the table).
/// - A line under it, small's detail and attention row, and medium's rows are one line at full
///   size. Where a label or a condition's words don't fit, the widget shows the shorter key
///   (``BatteryWidgetField/shortLabelKey``, ``WidgetCondition/shortKey``), so a place fits when one
///   of them does.
/// - A message (an empty state) wraps; the Russian takes as many lines as the English.
/// - Large's and extra large's tiles hold a label on one line over a value on up to two.
enum WidgetTextBudget {
    /// The main value's minimum scale factor (0.6.1's hero number).
    static let mainScaleFactor = 0.7
    /// The main value's width in characters at full size: the charge block is as wide in every size.
    static let mainCharacters = 7.0
    /// The share of a place a text may fill, for the estimate's error.
    static let margin = 0.98

    /// A text style, as its width relative to the caption.
    enum Style: Double, Sendable {
        case caption = 1
        /// The no-battery message's hint: 3 % wider than the caption in CI's pictures.
        case caption2 = 1.03
        /// A tile's value: 15 points, medium weight.
        case title3 = 1.56
    }

    /// A line under the main value: small's whole width, medium's charge block, large's whole
    /// width, an extra large panel. Small's detail and attention row are such lines.
    static func lineWidth(_ size: WidgetSize) -> Double {
        switch size {
        case .small: 136
        case .medium: 148
        case .large: 332
        case .extraLarge, .extraLargePortrait: 350
        }
    }

    /// A detail: small's line, medium's row beside the charge block, a tile of large's or extra
    /// large's two columns.
    static func detailWidth(_ size: WidgetSize) -> Double {
        switch size {
        case .small: 136
        case .medium: 148
        case .large: 160
        case .extraLarge, .extraLargePortrait: 169
        }
    }

    /// The widget's whole width inside its margins: an empty state's message, the Accessories
    /// widget's lines.
    static func contentWidth(_ size: WidgetSize) -> Double {
        switch size {
        case .small: 136
        case .medium, .large: 332
        case .extraLarge, .extraLargePortrait: 736
        }
    }

    /// The attention row's symbol before its words, with its spacing.
    static let symbolWidth = 17.0
    /// A tier's symbol before a value, with its spacing.
    static let cueWidth = 12.0

    /// Between a label and its value: small's line keeps them 4 points apart, medium's row at
    /// least 8.
    static func gap(_ size: WidgetSize) -> Double {
        size == .small ? 4 : 8
    }

    /// Whether a text `width` points wide fits a `place` points wide, with ``margin`` to spare.
    static func fits(_ width: Double, in place: Double) -> Bool {
        width <= place * margin
    }

    /// Whether `text` fits the main value's place once shrunk to ``mainScaleFactor``.
    static func fitsMain(_ text: String) -> Bool {
        Double(text.count) * mainScaleFactor <= mainCharacters
    }

    /// The lines `text` takes in a place `width` points wide: word by word, a line breaking at a
    /// space (never a no-break one) when the next word wouldn't fit, as macOS fills a line. The
    /// whole width counts; a caller that wants ``margin`` passes it.
    static func lines(_ text: String, width: Double, _ style: Style = .caption) -> Int {
        let space = self.width(" ", style)
        var lines = 1
        var line = 0.0
        for word in text.split(separator: " ") {
            let next = self.width(String(word), style)
            if line > 0 && line + space + next > width {
                lines += 1
                line = next
            } else {
                line += (line > 0 ? space : 0) + next
            }
        }
        return lines
    }

    /// `text`'s width in points in `style`, with `monospacedDigits` as medium's values have them
    /// (each digit as wide as the widest). A character outside the table counts as a wide letter.
    static func width(_ text: String, _ style: Style = .caption, monospacedDigits: Bool = false) -> Double {
        var points = 0.0
        for scalar in text.unicodeScalars {
            let value = Int(scalar.value)
            if monospacedDigits && (0x30...0x39).contains(value) {
                points += widestDigit
            } else if (0x20...0x7E).contains(value) {
                points += ascii[value - 0x20]
            } else if (0x410...0x44F).contains(value) {
                points += cyrillic[value - 0x410]
            } else {
                points += others[value] ?? unknown
            }
        }
        return points * style.rawValue
    }

    private static let widestDigit = 6.6
    private static let unknown = 8.0

    /// U+0020 to U+007E.
    private static let ascii: [Double] = [
        2.9, 2.9, 4.7, 6.4, 6.5, 10.0, 6.5, 3.0, 3.7, 3.7, 5.1, 6.7, 2.9, 4.7, 2.9, 3.7,
        6.4, 4.1, 6.2, 6.3, 6.6, 6.2, 6.3, 5.7, 6.3, 6.3, 2.9, 3.1, 6.7, 6.7, 6.7, 5.2,
        9.8, 7.0, 6.6, 7.4, 7.3, 6.1, 6.0, 7.6, 7.5, 2.7, 5.8, 6.8, 5.7, 9.2, 7.6, 7.8,
        6.5, 7.8, 6.5, 6.5, 6.6, 7.6, 7.0, 10.0, 6.9, 6.9, 6.4, 3.7, 3.7, 3.7, 4.8, 4.6,
        3.3, 5.7, 6.2, 5.8, 6.2, 5.9, 3.8, 6.2, 6.0, 2.5, 2.5, 5.6, 2.5, 8.9, 6.0, 6.1,
        6.2, 6.2, 3.8, 5.4, 3.3, 6.0, 5.7, 8.3, 5.5, 5.7, 5.6, 4.3, 3.4, 4.3, 6.7,
    ]

    /// U+0410 to U+044F, the basic Cyrillic capitals and small letters.
    private static let cyrillic: [Double] = [
        7.0, 6.6, 6.6, 5.9, 8.3, 6.1, 9.7, 6.3, 7.6, 7.6, 6.8, 7.6, 9.2, 7.5, 7.8, 7.5,
        6.5, 7.4, 6.6, 6.4, 8.4, 6.9, 7.3, 7.1, 9.7, 9.9, 8.3, 9.0, 6.6, 7.4, 10.3, 6.5,
        5.7, 6.0, 5.7, 4.4, 6.4, 5.9, 8.2, 5.0, 6.0, 6.0, 5.5, 5.8, 7.8, 6.0, 6.1, 6.0,
        6.2, 5.8, 4.7, 5.7, 7.0, 5.5, 6.1, 5.9, 8.3, 8.5, 6.5, 7.5, 5.7, 5.7, 8.6, 5.6,
    ]

    /// The other characters the widget's words and numbers use: the Cyrillic Yo, quotation marks,
    /// the ellipsis, the minus sign, the middle dot, the degree sign, dashes and the spaces.
    private static let others: [Int: Double] = [
        0x0401: 6.1, 0x0451: 5.9, 0x00AB: 5.9, 0x00BB: 5.9, 0x2026: 8.8, 0x2212: 6.7, 0x00B7: 2.9,
        0x00B0: 4.6, 0x00A0: 2.9, 0x202F: 1.8, 0x2013: 5.1, 0x2014: 10.2, 0x2019: 2.6, 0x201C: 4.5,
        0x201D: 4.5,
    ]
}

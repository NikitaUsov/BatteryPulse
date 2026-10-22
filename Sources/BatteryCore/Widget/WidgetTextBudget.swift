/// How much text each place of the widget holds, so a long translation is caught on Linux rather
/// than seen cut off on a Mac. Widths are in characters of caption text at full size, from the
/// 0.6.1 widget's layout [estimate]; text that may shrink counts at its smallest scale.
///
/// - The main value is the 34-point number, which shrinks to ``mainScaleFactor``.
/// - A line under it (a state, a time, "Updated 14:05", small's one detail or attention row) is
///   one line that shrinks to ``textScaleFactor`` as a whole, then truncates.
/// - A detail row's label shrinks to ``textScaleFactor``; its value never shrinks or truncates.
/// - A message (an empty state) wraps over up to three lines.
public enum WidgetTextBudget {
    /// The main value's minimum scale factor (0.6.1's hero number).
    public static let mainScaleFactor = 0.7
    /// Lines' and labels' minimum scale factor (0.6.1's labels).
    public static let textScaleFactor = 0.8
    /// A symbol beside text takes about two characters.
    static let symbolWidth = 2.0
    /// Between a row's label and its value.
    static let rowGap = 1.0

    public enum Slot: Sendable, CaseIterable {
        case main, line, row, message
    }

    /// The slot's width in characters at full size.
    public static func width(_ slot: Slot, _ size: WidgetSize) -> Double {
        switch (slot, size) {
        // The charge block is as wide in every size.
        case (.main, _): 7
        case (.line, _): 24
        // Small's one detail is a line, in the time line's place.
        case (.row, .small): 24
        // A 20-character label and a 9-character value.
        case (.row, .medium): 29
        // A 26-character label and a 9-character value: a large widget's column, or an extra
        // large one's panel.
        case (.row, .large), (.row, .extraLarge), (.row, .extraLargePortrait): 35
        case (.message, _): 3 * 24
        }
    }

    /// Whether `text` fits `slot` in `size`: in a row, `text` is the label and `value` the value
    /// beside it; elsewhere `value` is unused. `symbol` adds a symbol beside the text.
    public static func fits(_ text: String, value: String = "", symbol: Bool = false, in slot: Slot, size: WidgetSize)
        -> Bool
    {
        let symbols = symbol ? symbolWidth : 0
        let characters: Double =
            switch slot {
            case .main: Double(text.count) * mainScaleFactor
            case .line: Double(text.count) * textScaleFactor + symbols
            case .row where value.isEmpty: Double(text.count) * textScaleFactor + symbols
            case .row: Double(text.count) * textScaleFactor + symbols + rowGap + Double(value.count)
            case .message: Double(text.count)
            }
        return characters <= width(slot, size)
    }
}

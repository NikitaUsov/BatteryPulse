#if os(macOS)
import SwiftUI

/// Choices side by side as tiles, each a preview with its name below, like the Icon & widget
/// style tiles of macOS: the menu bar's icon styles and the window styles. Every tile gives its
/// preview the same frame, so the tiles match.
///
/// The selected tile is marked by an accent outline only, as System Settings marks its appearance
/// thumbnails: every tile keeps the same standard fill, so a preview looks the same selected or
/// not, and nothing is glass. The outline crossfades to the new tile. The choice itself is set
/// without animation: only the tiles animate, never what the choice changes.
///
/// A tile can carry a badge (the window styles' Beta) in its preview's top corner, so every tile
/// keeps the same height.
struct PreviewTilePicker<Value: RawRepresentable & Hashable, Preview: View>: View where Value.RawValue == String {
    @Binding var selection: Value
    let values: [Value]
    let title: (Value) -> LocalizedStringKey
    let badge: (Value) -> Text?
    let preview: (Value) -> Preview
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motion) private var motion
    @Environment(\.accessibilityShowBorders) private var showsBorders

    init(
        selection: Binding<Value>, values: [Value], title: @escaping (Value) -> LocalizedStringKey,
        badge: @escaping (Value) -> Text? = { _ in nil }, @ViewBuilder preview: @escaping (Value) -> Preview
    ) {
        _selection = selection
        self.values = values
        self.title = title
        self.badge = badge
        self.preview = preview
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(values, id: \.self) { value in
                tile(value)
            }
        }
        // The outline is a colour change, so it crossfades; nothing moves.
        .animation(motion.crossfade, value: selection)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func tile(_ value: Value) -> some View {
        let isSelected = value == selection
        let shape = RoundedRectangle(cornerRadius: PreviewTile.cornerRadius)
        return Button {
            selection = value
        } label: {
            VStack(spacing: 8) {
                preview(value)
                    .frame(height: PreviewTile.previewHeight)
                    .overlay(alignment: .topTrailing) {
                        if let badge = badge(value) {
                            TileBadge(text: badge)
                        }
                    }
                Text(title(value))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(.fill.quaternary, in: shape)
            .overlay {
                // Show Borders: every tile gets a visible edge, not only the selected one.
                if showsBorders {
                    shape.strokeBorder(.separator, lineWidth: 1)
                }
            }
            .overlay {
                shape.strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title(value)))
        .accessibilityValue(badge(value) ?? Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small mark in a tile's corner, such as Beta: plain text on the window's background with a
/// hairline, readable over any preview drawing.
private struct TileBadge: View {
    let text: Text

    var body: some View {
        text
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.background, in: .capsule)
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .padding(4)
    }
}

/// The tiles' measurements; a generic type can't store them.
enum PreviewTile {
    static let cornerRadius: CGFloat = 8
    /// Every preview's height: a window style's drawing (``WindowLookPreview``).
    static let previewHeight: CGFloat = WindowLookPreview.size.height
    /// The menu bar icons are drawn larger in a tile this size; each still takes the same frame
    /// (``BatteryIconLayout/previewSize``).
    static let iconMagnification: CGFloat = 2.5
}
#endif

#if os(macOS)
import BatteryCore
import SwiftUI

/// Clear's warning: a solid white capsule with dark text and a symbol, as the clear Home Screen
/// turns red badges white. The most legible mark on the glass, so it needs no colour; VoiceOver
/// reads its text.
struct InvertedBadge: View {
    let text: Text

    var body: some View {
        Label {
            text
        } icon: {
            Image(systemName: ToneBadge.symbolName)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color(white: ToneMap.ink))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.white.opacity(0.95), in: .capsule)
    }
}
#endif

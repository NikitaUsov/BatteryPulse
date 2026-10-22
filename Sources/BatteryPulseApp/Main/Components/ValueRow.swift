#if os(macOS)
import BatteryCore
import SwiftUI

/// A Form row with a label and a monospaced value; medium weight on the glass sheet.
struct ValueRow: View {
    let label: LocalizedStringKey
    let value: String
    @Environment(\.windowLook) private var look

    init(_ label: LocalizedStringKey, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .monospacedDigit()
                .textSelection(.enabled)
        }
        .fontWeight(look.boldNumerals ? .medium : nil)
        .contentTreatment()
    }
}
#endif

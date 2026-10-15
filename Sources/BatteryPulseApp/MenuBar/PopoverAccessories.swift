#if os(macOS)
import BatteryCore
import SwiftUI

/// The menu bar panel's accessories: a row each, with the charge of every part. Not buttons; the
/// Accessories page has the details.
struct PopoverAccessories: View {
    let accessories: [AccessoryBattery]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accessories")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(accessories) { accessory in
                PopoverAccessoryRow(accessory: accessory)
            }
        }
    }
}

/// The symbol, the name and the parts. The name truncates; the numbers never do.
private struct PopoverAccessoryRow: View {
    let accessory: AccessoryBattery

    var body: some View {
        HStack(spacing: 8) {
            AccessorySymbol(name: accessory.symbolName)
                .frame(width: 18)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(verbatim: Phrases.accessoryName(accessory))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(0)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                ForEach(accessory.parts, id: \.role) { part in
                    PopoverAccessoryPart(part: part, hasParts: accessory.hasParts)
                }
            }
            .fixedSize()
            .layoutPriority(1)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }
}

/// A part's symbol (with parts), its charge and a bolt while it charges.
private struct PopoverAccessoryPart: View {
    let part: AccessoryPart
    let hasParts: Bool
    private let formatter = BatteryFormatter.app

    var body: some View {
        let percent = formatter.percent(Double(part.percent))
        HStack(spacing: 2) {
            if hasParts, let symbol = part.role.symbolName, AccessorySymbols.isAvailable(symbol) {
                Image(systemName: symbol)
                    .font(.caption)
            }
            Text(verbatim: percent)
                .monospacedDigit()
                .foregroundStyle(color)
            if part.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Phrases.accessoryPart(part.role, hasParts: hasParts)))
        .accessibilityValue(Text(verbatim: accessibilityValue(percent)))
    }

    /// Dimmed while offline (the last charge reported), orange or red when low, plain otherwise.
    private var color: Color {
        if part.isOffline { return .secondary }
        let tier = BatteryPresentation.levelTier(percent: Double(part.percent), isCharging: part.isCharging)
        return tier == .normal ? .primary : tier.color
    }

    private func accessibilityValue(_ percent: String) -> String {
        guard part.isCharging else { return percent }
        return String(localized: "\(percent), charging")
    }
}
#endif

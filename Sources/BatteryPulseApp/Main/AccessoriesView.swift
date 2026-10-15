#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

/// The Accessories page: a card per connected accessory with the charge of each of its parts.
/// It needs no battery, so it shows on a Mac without one too.
struct AccessoriesView: View {
    let monitor: AccessoryMonitor

    var body: some View {
        content
            .refreshesWhenShown(monitor)
    }

    // Cards come and go without animation: an accessory connecting is not the user's action.
    @ViewBuilder
    private var content: some View {
        if monitor.isAvailable == false {
            ContentUnavailableView(
                "Accessories Unavailable",
                systemImage: AccessoryKind.fallbackSymbolName,
                description: Text("This version of macOS doesn't report accessory batteries to apps.")
            )
        } else if monitor.isAvailable == nil {
            ProgressView()
        } else if monitor.accessories.isEmpty {
            ContentUnavailableView(
                "No Accessories",
                systemImage: AccessoryKind.fallbackSymbolName,
                description: Text(
                    "Connect a Bluetooth keyboard, mouse, trackpad or headphones to see its battery here.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CardGroup {
                        VStack(spacing: 16) {
                            ForEach(monitor.accessories) { accessory in
                                AccessoryCard(accessory: accessory)
                            }
                        }
                    }
                    Text("Accessories show here while they're connected to this Mac.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// One accessory: its symbol, name, kind and connection, then a row per part.
private struct AccessoryCard: View {
    let accessory: AccessoryBattery

    var body: some View {
        Card {
            HStack(spacing: 12) {
                AccessorySymbol(name: accessory.symbolName)
                    .font(.title2)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: Phrases.accessoryName(accessory))
                        .font(.headline)
                    Text(verbatim: Phrases.accessoryDetails(accessory))
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(accessory.parts, id: \.role) { part in
                AccessoryPartRow(part: part, hasParts: accessory.hasParts)
            }
        }
    }
}

/// A part's label, its state, its charge and a level bar in the colours of the Mac's battery.
private struct AccessoryPartRow: View {
    let part: AccessoryPart
    let hasParts: Bool
    private let formatter = BatteryFormatter.app

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: Phrases.accessoryPart(part.role, hasParts: hasParts))
                if let status = Phrases.accessoryStatus(part) {
                    Text(verbatim: status)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(verbatim: formatter.percent(Double(part.percent)))
                    .monospacedDigit()
                    .numericValue(Double(part.percent))
            }
            ProgressView(value: Double(part.percent), total: 100)
                .tint(tint)
        }
    }

    /// An offline part shows its last charge, dimmed.
    private var tint: Color {
        guard !part.isOffline else { return .secondary }
        return BatteryPresentation.levelTier(percent: Double(part.percent), isCharging: part.isCharging).color
    }
}

/// An accessory's SF Symbol, or the generic one where this macOS lacks it.
struct AccessorySymbol: View {
    let name: String

    var body: some View {
        Image(systemName: AccessorySymbolCache.available(name) ? name : AccessoryKind.fallbackSymbolName)
    }
}

/// Which symbol names this macOS has, each checked once.
@MainActor
private enum AccessorySymbolCache {
    private static var known: [String: Bool] = [:]

    static func available(_ name: String) -> Bool {
        if let available = known[name] { return available }
        let available = NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        known[name] = available
        return available
    }
}

extension View {
    /// One accessory read each time this view's window becomes visible. The menu bar panel's
    /// content stays alive between openings, so `onAppear` alone would not repeat; this follows
    /// `motion.isVisible`, as `liveRefresh` does. It catches anything missed over sleep.
    func refreshesWhenShown(_ monitor: AccessoryMonitor) -> some View {
        modifier(RefreshWhenShown(monitor: monitor))
    }
}

private struct RefreshWhenShown: ViewModifier {
    let monitor: AccessoryMonitor
    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        content
            .onAppear {
                if motion.isVisible { monitor.refresh() }
            }
            .onChange(of: motion.isVisible) { _, isVisible in
                if isVisible { monitor.refresh() }
            }
    }
}
#endif

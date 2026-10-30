#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

/// An accessory's SF Symbol, or the generic one where this macOS lacks it.
struct AccessorySymbol: View {
    let name: String

    var body: some View {
        Image(systemName: AccessorySymbols.isAvailable(name) ? name : AccessoryKind.fallbackSymbolName)
    }
}

/// Which symbol names this macOS has, each checked once.
enum AccessorySymbols {
    private static var known: [String: Bool] = [:]

    static func isAvailable(_ name: String) -> Bool {
        if let available = known[name] { return available }
        let available = NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        known[name] = available
        return available
    }
}
#endif

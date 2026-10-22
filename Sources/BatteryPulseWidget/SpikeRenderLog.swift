#if os(macOS)
import Foundation
import SwiftUI
import WidgetKit
import os

/// SPIKE-W (docs/plans/0.6.2/PLAN.md, WP-W0, W0-4 (2) and (3)), spike branch only: one line per
/// render of a widget view with its family, rendering mode, whether the system shows the container
/// background, the redaction reasons and the colour scheme, all as case names. Session A switches
/// Icon & widget style and Dim widgets on desktop, on the desktop and in Notification Center, and
/// reads which mode each gives and whether `.privacy` ever appears.
struct SpikeRenderLog: ViewModifier {
    /// The kind that rendered, as the log names it.
    let kind: String
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        // Logging while SwiftUI evaluates the body: a widget view has no other moment of its own.
        let _ = log()
        content
    }

    private func log() {
        let kindName = kind
        let familyName = SpikeNames.family(family)
        let mode = SpikeNames.renderingMode(renderingMode)
        let background = showsBackground
        let redaction = SpikeNames.redaction(redactionReasons)
        let scheme = colorScheme == .dark ? "dark" : "light"
        spikeLog.notice(
            "spike render kind=\(kindName, privacy: .public) family=\(familyName, privacy: .public) mode=\(mode, privacy: .public) background=\(background, privacy: .public) redaction=\(redaction, privacy: .public) scheme=\(scheme, privacy: .public)"
        )
    }
}

/// The page a click on the medium battery widget asks for: §8.9's natural page per main value, as
/// `batterypulse://page/<id>`. No app registers the scheme (W0-4 (5)).
enum SpikeRoute {
    static let scheme = "batterypulse"

    static func url(for options: BatteryWidgetOptions) -> URL? {
        let page =
            switch options.mainValue {
            case .charge: "overview"
            case .maximumCapacity: "health"
            case .temperature, .batteryPower: "power"
            }
        return URL(string: "\(scheme)://page/\(page)")
    }
}

/// Case names for the spike's log lines.
enum SpikeNames {
    static func family(_ family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: "small"
        case .systemMedium: "medium"
        case .systemLarge: "large"
        case .systemExtraLarge: "extraLarge"
        default: "other"
        }
    }

    /// `WidgetRenderingMode` is a struct of static values, not an enum; an unknown one logs its
    /// description, which the system writes.
    static func renderingMode(_ mode: WidgetRenderingMode) -> String {
        if mode == .fullColor { return "fullColor" }
        if mode == .accented { return "accented" }
        if mode == .vibrant { return "vibrant" }
        return "other(\(mode.description))"
    }

    /// The reasons joined by "+", or "none".
    static func redaction(_ reasons: RedactionReasons) -> String {
        var names: [String] = []
        if reasons.contains(.placeholder) { names.append("placeholder") }
        if reasons.contains(.privacy) { names.append("privacy") }
        if reasons.contains(.invalidated) { names.append("invalidated") }
        if !reasons.subtracting([.placeholder, .privacy, .invalidated]).isEmpty { names.append("other") }
        return names.isEmpty ? "none" : names.joined(separator: "+")
    }
}
#endif

#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing

// Temporary, removed in the next commit: the S-1 review's probe (plan-0.7.1). It measures on CI's
// macOS a page under a cap it fits in (no scroll bar, nothing to scroll), beside one that doesn't
// fit, inside a copy of the app's CappedHeightLayout in a window. It logs to standard error and
// never fails.

private func probeLog(_ line: String) {
    FileHandle.standardError.write(Data("S-1 review probe: \(line)\n".utf8))
}

/// Three sections of `count` rows: toggles, plus rows of fractional heights and a wrapped text
/// when `fractional`.
private struct ReviewRows: View {
    var count: Int
    var fractional: Bool

    var body: some View {
        ForEach(0..<3, id: \.self) { section in
            Section {
                ForEach(0..<count, id: \.self) { row in
                    if fractional {
                        Text(verbatim: "Row \(row)").frame(height: 21.37)
                    } else {
                        Toggle(isOn: .constant(row.isMultiple(of: 2))) { Text(verbatim: "Row \(row)") }
                    }
                }
                if fractional {
                    Text(verbatim: String(repeating: "wrapped words ", count: 23))
                }
            } header: {
                Text(verbatim: "Section \(section)")
            }
        }
    }
}

/// The app's CappedHeightLayout, copied.
private struct ReviewCapped: Layout {
    var cap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let page = subviews.first else { return .zero }
        let ideal = page.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: ideal.width, height: min(ideal.height, cap))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}

@MainActor
struct SettingsFitProbe {
    private func scrollViews(in view: NSView?) -> [NSScrollView] {
        guard let view else { return [] }
        var found: [NSScrollView] = []
        if let scroll = view as? NSScrollView { found.append(scroll) }
        for subview in view.subviews { found += scrollViews(in: subview) }
        return found
    }

    private func describe(_ scroll: NSScrollView) -> String {
        let clip = scroll.contentView
        let document = scroll.documentView?.frame.size ?? .zero
        // Where the clip view would let a scroll of 50 points down go: 0 when nothing scrolls.
        let request = NSRect(origin: NSPoint(x: 0, y: clip.bounds.origin.y + 50), size: clip.bounds.size)
        let constrained = clip.constrainBoundsRect(request).origin.y - clip.bounds.origin.y
        let scroller = scroll.verticalScroller
        return
            "clip \(clip.bounds.size), document \(document), scroll of 50 gives \(constrained), elasticity \(scroll.verticalScrollElasticity.rawValue), style \(scroll.scrollerStyle.rawValue), has scroller \(scroll.hasVerticalScroller), scroller hidden \(scroller?.isHidden.description ?? "none"), alpha \(scroller?.alphaValue ?? -1)"
    }

    private func inspect(_ name: String, cap: CGFloat, rows: ReviewRows) async throws {
        let view = ReviewCapped(cap: cap) {
            Form { rows }.formStyle(.grouped).scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 500)
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.minSize, .maxSize, .preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .resizable]
        window.orderFrontRegardless()
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        window.contentView?.layoutSubtreeIfNeeded()
        probeLog(
            "\(name): window \(window.frame.size), content \(window.contentView?.frame.size ?? .zero), min \(window.contentMinSize), max \(window.contentMaxSize)"
        )
        for scroll in scrollViews(in: window.contentView) {
            probeLog("\(name):   \(type(of: scroll)) \(describe(scroll))")
            // As with System Settings > Appearance > Show scroll bars: Always.
            scroll.scrollerStyle = .legacy
            scroll.tile()
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(200))
            probeLog("\(name):   legacy: \(describe(scroll))")
        }
        window.orderOut(nil)
    }

    @Test func aPageThatFitsDoesNotScroll() async throws {
        _ = NSApplication.shared
        probeLog("preferred scroller style \(NSScroller.preferredScrollerStyle.rawValue)")
        try await inspect("fits, toggles", cap: 1_000, rows: ReviewRows(count: 3, fractional: false))
        try await inspect("fits, fractional", cap: 2_000, rows: ReviewRows(count: 7, fractional: true))
        try await inspect("capped, fractional", cap: 300, rows: ReviewRows(count: 7, fractional: true))
        try await inspect("capped, toggles", cap: 400, rows: ReviewRows(count: 40, fractional: false))
    }
}
#endif

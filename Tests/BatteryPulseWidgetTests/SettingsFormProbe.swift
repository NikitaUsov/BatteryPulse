#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing

// Temporary, removed in the next commit: measures on CI's macOS how a grouped Form sizes with
// scrolling on and off, and inside a capped layout like the app's CappedHeightLayout, for S-1
// (plan-0.7.1). It logs to standard error and never fails.

private func probeLog(_ line: String) {
    FileHandle.standardError.write(Data("S-1 probe: \(line)\n".utf8))
}

/// Three sections of `count` toggles each.
private struct ProbeRows: View {
    var count: Int

    var body: some View {
        ForEach(0..<3, id: \.self) { section in
            Section {
                ForEach(0..<count, id: \.self) { row in
                    Toggle(isOn: .constant(row.isMultiple(of: 2))) { Text(verbatim: "Row \(row)") }
                }
            } header: {
                Text(verbatim: "Section \(section)")
            }
        }
    }
}

/// The app's CappedHeightLayout, copied.
private struct ProbeCapped: Layout {
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
struct SettingsFormProbe {
    private func measure(_ name: String, _ view: some View) {
        let controller = NSHostingController(rootView: view)
        let fitted = controller.sizeThatFits(in: CGSize(width: 500, height: 100_000))
        let host = NSHostingView(rootView: view)
        probeLog("\(name): sizeThatFits(500 x 100000) \(fitted), fittingSize \(host.fittingSize)")
    }

    private func scrollViews(in view: NSView?) -> [NSScrollView] {
        guard let view else { return [] }
        var found: [NSScrollView] = []
        if let scroll = view as? NSScrollView { found.append(scroll) }
        for subview in view.subviews { found += scrollViews(in: subview) }
        return found
    }

    private func classNames(in view: NSView?, depth: Int = 0) -> [String] {
        guard let view, depth < 14 else { return [] }
        var names = ["\(String(repeating: " ", count: depth))\(type(of: view)) \(view.frame.size)"]
        for subview in view.subviews { names += classNames(in: subview, depth: depth + 1) }
        return names
    }

    private func inspectWindow(_ name: String, _ view: some View) async throws {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable]
        window.orderFrontRegardless()
        window.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        window.contentView?.layoutSubtreeIfNeeded()
        probeLog(
            "\(name): window \(window.frame.size), content \(window.contentView?.frame.size ?? .zero), preferred \(controller.preferredContentSize)"
        )
        let scrolls = scrollViews(in: window.contentView)
        for scroll in scrolls {
            let document = scroll.documentView?.frame.size ?? .zero
            probeLog(
                "\(name):   \(type(of: scroll)) frame \(scroll.frame.size), clip \(scroll.contentView.bounds.size), document \(document), elasticity \(scroll.verticalScrollElasticity.rawValue), scroller \(scroll.hasVerticalScroller), autohides \(scroll.autohidesScrollers)"
            )
        }
        if scrolls.isEmpty {
            for line in classNames(in: window.contentView) { probeLog("\(name):   \(line)") }
        }
        window.orderOut(nil)
    }

    @Test func groupedFormHeights() {
        _ = NSApplication.shared
        for count in [3, 40] {
            let rows = ProbeRows(count: count)
            let disabled = Form { rows }.formStyle(.grouped).scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true).frame(width: 500)
            measure("A rows \(count), scrollDisabled and fixedSize", disabled)
            let enabled = Form { rows }.formStyle(.grouped).fixedSize(horizontal: false, vertical: true)
                .frame(width: 500)
            measure("B rows \(count), fixedSize, scrolling on", enabled)
            let capped = ProbeCapped(cap: 400) {
                Form { rows }.formStyle(.grouped).scrollBounceBehavior(.basedOnSize)
            }
            .frame(width: 500)
            measure("C rows \(count), capped at 400, scrolling on", capped)
            let wrapped = ProbeCapped(cap: 400) {
                ScrollView {
                    Form { rows }.formStyle(.grouped).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(width: 500)
            measure("E rows \(count), capped at 400, a ScrollView around the disabled Form", wrapped)
        }
    }

    @Test func groupedFormInAWindow() async throws {
        _ = NSApplication.shared
        for count in [3, 40] {
            let rows = ProbeRows(count: count)
            let capped = ProbeCapped(cap: 400) {
                Form { rows }.formStyle(.grouped).scrollBounceBehavior(.basedOnSize)
            }
            .frame(width: 500)
            try await inspectWindow("C window, rows \(count)", capped)
            let disabled = Form { rows }.formStyle(.grouped).scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true).frame(width: 500)
            try await inspectWindow("A window, rows \(count)", disabled)
        }
    }
}
#endif

#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI
import UniformTypeIdentifiers

/// Everything behind the numbers, for the curious: the raw dictionaries macOS reports, decoded
/// and explained where the meaning is known. Hidden unless enabled in Settings → Advanced.
struct DeveloperView: View {
    let monitor: BatteryMonitor
    @State private var filter = ""
    /// The source picked in the toolbar; `nil` shows every section.
    @State private var source: RawSectionGroup?
    @State private var selection: Set<RawRow.ID> = []
    @State private var showsInspector = false
    /// The table for the current reading. Built off the main actor when the reading changes, not
    /// on every body evaluation: showing the inspector or typing in the filter re-evaluates the
    /// body, and the main window reads the battery every 2 s.
    @State private var allSections: [RawSection] = []
    @Environment(\.motion) private var motion
    @Environment(\.windowLook) private var look

    var body: some View {
        let groups = RawSectionGroup.groups(in: allSections)
        // A source that this reading lacks (the adapter's details after unplugging) shows all.
        let shownGroup = source.flatMap { groups.contains($0) ? $0 : nil }
        let sections = filteredSections(in: shownGroup)
        // The Liquid Glass sidebar floats over the detail column, and a scroll view whose edge
        // touches it is stretched underneath. A Table wider than it shows then starts at the
        // window edge with its Key column behind the sidebar. A point of padding keeps it clear of
        // that edge, so it is laid out beside the sidebar like the Form pages.
        rawTable(sections)
            // On the glass sheet the rows sit on the sheet, without stripes; Frosted keeps the
            // table's opaque surface, which long keys and hex values need.
            .scrollContentBackground(look.usesGlassSheet ? .hidden : .automatic)
            .alternatingRowBackgrounds(look.usesGlassSheet ? .disabled : .automatic)
            .padding(.leading, 1)
            .overlay {
                // Only the empty state fades; the table's rows never animate.
                ZStack {
                    if sections.isEmpty, !filter.isEmpty {
                        ContentUnavailableView.search(text: filter)
                            .transition(.opacity)
                    }
                }
                .animation(motion.crossfade, value: sections.isEmpty)
            }
            // Clear's treatment goes on the table as one group, with the sheet's text levels.
            .sheetContent()
            .searchable(text: $filter, placement: .toolbar, prompt: "Filter keys, values and descriptions")
            // The table cuts long values and descriptions off; the inspector shows the selected
            // row in full.
            .inspector(isPresented: $showsInspector) {
                RawRowInspector(selection: inspectedRows)
                    .inspectorColumnWidth(min: 240, ideal: 300, max: 440)
            }
            .toolbar {
                // A switch between the dictionaries. It filters the table to one source rather
                // than scrolling to it: a Table has no documented way to scroll to a section.
                // A pop-up menu, not a segmented control: a MacBook reading has six or seven
                // sources, and eight segments ("All" included) don't fit beside the title, the
                // search field and the page's buttons at the main window's default width, least
                // of all in Russian. A menu keeps every action in the toolbar visible, at any
                // number of sources and in either language.
                if groups.count > 1 {
                    ToolbarItem(placement: .principal) {
                        Picker("Source", selection: $source) {
                            Text("All").tag(RawSectionGroup?.none)
                            ForEach(groups, id: \.self) { group in
                                Self.title(of: group).tag(RawSectionGroup?.some(group))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                        .help("Show only the values from one source")
                    }
                }
                ToolbarItem {
                    Button("Inspector", systemImage: "sidebar.trailing") { showsInspector.toggle() }
                        .help("Show or hide the selected row in full")
                }
                // Showing the inspector and exporting are unrelated: separate glass capsules.
                ToolbarSpacer(.fixed)
                ToolbarItemGroup {
                    // Exports are for bug reports, so they are off while the data is simulated.
                    Button("Copy JSON", systemImage: "curlybraces", action: copyJSON)
                        .disabled(monitor.isOverridden)
                        .help(
                            monitor.isOverridden
                                ? Text("Not available in Demo Mode")
                                : Text("Copy the parsed readings as JSON, without serial numbers"))
                    Button("Export Capture…", systemImage: "square.and.arrow.up", action: exportCapture)
                        .disabled(monitor.isOverridden)
                        .help(
                            monitor.isOverridden
                                ? Text("Not available in Demo Mode")
                                : Text("Save the raw data for a bug report. Serial numbers are redacted."))
                }
            }
            .onChange(of: groups) { _, groups in
                // The switch then shows All selected, as the table does.
                if let source, !groups.contains(source) { self.source = nil }
            }
            .disabled(monitor.reading == nil)
            .task(id: monitor.reading) { await rebuild() }
    }

    /// The title of a source in the switch: short, and the API's own name where it has no other.
    private static func title(of group: RawSectionGroup) -> Text {
        switch group {
        case .battery: Text("Battery")
        case .pack: Text("Pack")
        case .banks: Text("Banks")
        case .charger: Text("Charger")
        case .powerSources: Text(verbatim: "IOPS")
        case .adapter: Text("Adapter")
        case .smc: Text(verbatim: "SMC")
        }
    }

    private func rebuild() async {
        guard let reading = monitor.reading else {
            allSections = []
            return
        }
        let sections = await Task.detached(priority: .userInitiated) {
            RawSection.sections(for: reading.redactedRawCapture)
        }.value
        // Identical readings leave the table alone. Assigned after an `await`, so outside any
        // animation, Demo Mode's included: hundreds of rows change with every reading and must
        // never animate.
        guard !Task.isCancelled, sections != allSections else { return }
        allSections = sections
    }

    /// A Table rather than a List: fixed-height rows keep live updates and window resizing cheap.
    private func rawTable(_ sections: [RawSection]) -> some View {
        Table(of: RawRow.self, selection: $selection) {
            TableColumn("Key") { row in
                Text(verbatim: row.path)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .help(row.path)
            }
            .width(min: 140, ideal: 230)
            TableColumn("Value") { row in
                Text(verbatim: row.value)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.value)
            }
            .width(min: 60, ideal: 90)
            TableColumn("Decoded") { row in
                if let decoded = row.decoded {
                    Text(RawValueText.string(for: decoded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fontWeight(look.boldNumerals ? .medium : nil)
                }
            }
            .width(min: 70, ideal: 130)
            TableColumn("Description") { row in
                if let summary = row.info?.summary {
                    let text = RawValueText.summary(summary)
                    Text(text)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fontWeight(look.boldNumerals ? .medium : nil)
                        .help(text)
                }
            }
            .width(min: 100, ideal: 260)
        } rows: {
            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        TableRow(row)
                    }
                } header: {
                    Text(verbatim: section.title)
                }
            }
        }
        .contextMenu(forSelectionType: RawRow.ID.self) { ids in
            Button("Show in Inspector") {
                selection = ids
                showsInspector = true
            }
            Divider()
            Button("Copy") { copy(ids, as: \.line) }
            Button("Copy Key") { copy(ids, as: \.path) }
            Button("Copy Value") { copy(ids, as: \.value) }
        } primaryAction: { ids in
            // Double-click opens the row in the inspector.
            selection = ids
            showsInspector = true
        }
        .onCopyCommand { providers(for: selection) }
        // Rows and cells never animate, whatever transaction reaches the table.
        .transaction { $0.animation = nil }
    }

    /// The selected rows with the title of the dictionary each comes from.
    private var inspectedRows: [(row: RawRow, source: String)] {
        allSections.flatMap { section in
            section.rows.filter { selection.contains($0.id) }.map { (row: $0, source: section.title) }
        }
    }

    /// The sections of `group` (all for `nil`) with the rows that match the filter.
    private func filteredSections(in group: RawSectionGroup?) -> [RawSection] {
        let sections = RawSectionGroup.sections(allSections, in: group)
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            var section = section
            section.rows = section.rows.filter { matches($0, query) }
            return section.rows.isEmpty ? nil : section
        }
    }

    private func matches(_ row: RawRow, _ query: String) -> Bool {
        if row.path.localizedCaseInsensitiveContains(query) || row.value.localizedCaseInsensitiveContains(query) {
            return true
        }
        if let decoded = row.decoded, RawValueText.string(for: decoded).localizedCaseInsensitiveContains(query) {
            return true
        }
        if let summary = row.info?.summary {
            return summary.localizedCaseInsensitiveContains(query)
                || RawValueText.summary(summary).localizedCaseInsensitiveContains(query)
        }
        return false
    }

    // MARK: - Copying

    private func rows(_ ids: Set<RawRow.ID>) -> [RawRow] {
        allSections.flatMap(\.rows).filter { ids.contains($0.id) }
    }

    private func copy(_ ids: Set<RawRow.ID>, as text: KeyPath<RawRow, String>) {
        let lines = rows(ids).map { $0[keyPath: text] }
        guard !lines.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func providers(for ids: Set<RawRow.ID>) -> [NSItemProvider] {
        let lines = rows(ids).map(\.line)
        guard !lines.isEmpty else { return [] }
        return [NSItemProvider(object: lines.joined(separator: "\n") as NSString)]
    }

    private func copyJSON() {
        guard var snapshot = monitor.snapshot, !monitor.isOverridden else { return }
        snapshot.serialNumber = nil
        snapshot.adapter?.serialNumber = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(String(decoding: data, as: UTF8.self), forType: .string)
    }

    private func exportCapture() {
        guard let reading = monitor.reading, !monitor.isOverridden else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = "BatteryPulse-capture.xml"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let plist = PropertyValue.dictionary(reading.redactedRawCapture).foundationValue
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// The selected raw value in full: key, source, description, value and decoding.
private struct RawRowInspector: View {
    let selection: [(row: RawRow, source: String)]

    var body: some View {
        if selection.count == 1, let row = selection.first?.row, let source = selection.first?.source {
            LookForm {
                Section("Key") {
                    Text(verbatim: row.path)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    LabeledContent("Source") {
                        Text(verbatim: source)
                    }
                }
                Section("Description") {
                    if let summary = row.info?.summary {
                        Text(RawValueText.summary(summary))
                            .textSelection(.enabled)
                    } else {
                        Text("No description for this key yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Value") {
                    Text(verbatim: row.value)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                if let decoded = row.decoded {
                    Section("Decoded") {
                        Text(RawValueText.string(for: decoded))
                            .textSelection(.enabled)
                    }
                }
            }
        } else if selection.isEmpty {
            ContentUnavailableView(
                "No Row Selected",
                systemImage: "sidebar.trailing",
                description: Text("Select a row to see its full value, decoding and description.")
            )
        } else {
            ContentUnavailableView(
                "Multiple Rows Selected",
                systemImage: "square.stack",
                description: Text("Select a single row to see it in full.")
            )
        }
    }
}

extension RawRow {
    /// `BatteryData.DesignCapacity = 5760`, for the clipboard.
    fileprivate var line: String { "\(path) = \(value)" }
}
#endif

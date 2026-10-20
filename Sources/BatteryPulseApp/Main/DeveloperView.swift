#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// Everything behind the numbers, for the curious: the raw dictionaries macOS reports, decoded
/// and explained where the meaning is known. Hidden unless enabled in Settings → Advanced.
struct DeveloperView: View {
    let monitor: BatteryMonitor
    @State private var filter = ""
    /// The source picked in the toolbar; `nil` shows every section.
    @State private var source: RawSectionGroup?
    @State private var selection: Set<RawDisplayRow.ID> = []
    @State private var showsInspector = false
    /// The table for the current reading, with every cell's text and each row's search text.
    /// Built off the main actor when the reading changes, not on every body evaluation: showing
    /// the inspector, selecting or typing in the filter re-evaluates the body, and the main window
    /// reads the battery every 2 s.
    @State private var allSections: [RawDisplaySection] = []
    /// The capture Export Capture hands to the system's Save panel, and why saving it failed.
    @State private var capture: CaptureFile?
    @State private var exportsCapture = false
    @State private var exportFailure: String?
    @Environment(\.motion) private var motion
    @Environment(\.windowLook) private var look

    var body: some View {
        let groups = RawSectionGroup.groups(in: allSections)
        // A source that this reading lacks (the adapter's details after unplugging) shows all.
        let shownGroup = source.flatMap { groups.contains($0) ? $0 : nil }
        let sections = Diagnostics.measure("raw.filter") { filteredSections(in: shownGroup) }
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
            // On the page rather than in the toolbar item, where presentations are unreliable on
            // macOS, and after `disabled`, so the alert's button works without a reading.
            .fileExporter(
                isPresented: $exportsCapture, item: capture, contentTypes: [.xml],
                defaultFilename: "BatteryPulse-capture.xml",
                onCompletion: { result in
                    if case .failure(let error) = result { exportFailure = error.localizedDescription }
                    capture = nil
                },
                onCancellation: { capture = nil }
            )
            .alert(Text("Couldn't Export Capture"), isPresented: exportFailureShown) {
                Button("OK") {}
            } message: {
                Text(verbatim: exportFailure ?? "")
            }
    }

    private var exportFailureShown: Binding<Bool> {
        Binding(get: { exportFailure != nil }, set: { if !$0 { exportFailure = nil } })
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
        let sections = await RawValueText.sections(for: reading)
        // Identical readings leave the table alone. Assigned after an `await`, so outside any
        // animation, Demo Mode's included: hundreds of rows change with every reading and must
        // never animate.
        guard !Task.isCancelled, sections != allSections else { return }
        allSections = sections
    }

    /// A Table rather than a List: fixed-height rows keep live updates and window resizing cheap.
    private func rawTable(_ sections: [RawDisplaySection]) -> some View {
        Table(of: RawDisplayRow.self, selection: $selection) {
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
                    Text(verbatim: decoded)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fontWeight(look.boldNumerals ? .medium : nil)
                }
            }
            .width(min: 70, ideal: 130)
            TableColumn("Description") { row in
                if let summary = row.summary {
                    Text(verbatim: summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fontWeight(look.boldNumerals ? .medium : nil)
                        .help(summary)
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
        .contextMenu(forSelectionType: RawDisplayRow.ID.self) { ids in
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
    private var inspectedRows: [(row: RawDisplayRow, source: String)] {
        allSections.flatMap { section in
            section.rows.filter { selection.contains($0.id) }.map { (row: $0, source: section.title) }
        }
    }

    /// The sections of `group` (all for `nil`) with the rows that match the filter: one search of
    /// each row's prepared text, which formats and translates nothing.
    private func filteredSections(in group: RawSectionGroup?) -> [RawDisplaySection] {
        RawDisplaySection.filter(RawSectionGroup.sections(allSections, in: group), by: filter)
    }

    // MARK: - Copying

    private func rows(_ ids: Set<RawDisplayRow.ID>) -> [RawDisplayRow] {
        allSections.flatMap(\.rows).filter { ids.contains($0.id) }
    }

    private func copy(_ ids: Set<RawDisplayRow.ID>, as text: KeyPath<RawDisplayRow, String>) {
        let lines = rows(ids).map { $0[keyPath: text] }
        guard !lines.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func providers(for ids: Set<RawDisplayRow.ID>) -> [NSItemProvider] {
        let lines = rows(ids).map(\.line)
        guard !lines.isEmpty else { return [] }
        return [NSItemProvider(object: lines.joined(separator: "\n") as NSString)]
    }

    private func copyJSON() {
        guard let snapshot = monitor.snapshot, !monitor.isOverridden else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot.redacted) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(String(decoding: data, as: UTF8.self), forType: .string)
    }

    /// Saves the redacted capture in the fixture format through the system's Save panel; a
    /// failure to write the file shows an alert.
    private func exportCapture() {
        guard let reading = monitor.reading, !monitor.isOverridden else { return }
        do {
            capture = CaptureFile(data: try PropertyValue.xmlPropertyListData(reading.redactedRawCapture))
            exportsCapture = true
        } catch {
            exportFailure = error.localizedDescription
        }
    }
}

/// A raw capture for the system's Save panel: the XML property list that `bpulse --raw` writes and
/// `bpulse --input` reads.
private struct CaptureFile: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .xml) { file in file.data }
    }
}

/// The selected raw value in full: key, source, description, value and decoding.
private struct RawRowInspector: View {
    let selection: [(row: RawDisplayRow, source: String)]

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
                    if let summary = row.summary {
                        Text(verbatim: summary)
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
                        Text(verbatim: decoded)
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

extension RawDisplayRow {
    /// `BatteryData.DesignCapacity = 5760`, for the clipboard.
    fileprivate var line: String { "\(path) = \(value)" }
}
#endif

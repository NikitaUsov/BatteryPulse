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
    @State private var selection: Set<RawRow.ID> = []

    var body: some View {
        let sections = filteredSections
        // A Table rather than a List: fixed-height rows keep live updates and window resizing cheap.
        Table(of: RawRow.self, selection: $selection) {
            TableColumn("Key") { row in
                Text(verbatim: row.path)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .help(row.path)
            }
            .width(min: 160, ideal: 280)
            TableColumn("Value") { row in
                Text(verbatim: row.value)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.value)
            }
            .width(min: 60, ideal: 110)
            TableColumn("Decoded") { row in
                if let decoded = row.decoded {
                    Text(RawValueText.string(for: decoded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .width(min: 70, ideal: 150)
            TableColumn("Description") { row in
                if let summary = row.info?.summary {
                    let text = RawValueText.summary(summary)
                    Text(text)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(text)
                }
            }
            .width(min: 120, ideal: 380)
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
            Button("Copy") { copy(ids, as: \.line) }
            Button("Copy Key") { copy(ids, as: \.path) }
            Button("Copy Value") { copy(ids, as: \.value) }
        }
        .onCopyCommand { providers(for: selection) }
        .overlay {
            if sections.isEmpty, !filter.isEmpty {
                ContentUnavailableView.search(text: filter)
            }
        }
        .searchable(text: $filter, placement: .toolbar, prompt: "Filter keys, values and descriptions")
        .toolbar {
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
        .disabled(monitor.reading == nil)
    }

    private var allSections: [RawSection] {
        monitor.reading.map { RawSection.sections(for: $0.redactedRawCapture) } ?? []
    }

    private var filteredSections: [RawSection] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return allSections }
        return allSections.compactMap { section in
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

extension RawRow {
    /// `BatteryData.DesignCapacity = 5760`, for the clipboard.
    fileprivate var line: String { "\(path) = \(value)" }
}
#endif

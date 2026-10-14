#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

/// Every reading, grouped, plus the raw IORegistry data behind them.
struct DetailsView: View {
    let monitor: BatteryMonitor
    @State private var showsRawData = false
    @State private var rawFilter = ""

    var body: some View {
        Form {
            if let snapshot = monitor.snapshot {
                ForEach(BatteryReport.sections(for: snapshot), id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.lines, id: \.label) { line in
                            LabeledContent(line.label) {
                                Text(line.value)
                                    .monospacedDigit()
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            } else {
                Text(monitor.hasBattery == false ? "This Mac has no internal battery." : "Reading the battery…")
                    .foregroundStyle(.secondary)
            }

            if let reading = monitor.reading {
                Section {
                    DisclosureGroup("Raw IORegistry data", isExpanded: $showsRawData) {
                        TextField("Filter keys", text: $rawFilter)
                        // Flattened only while expanded: hundreds of rows, refreshed every 2 s.
                        if showsRawData {
                            ForEach(rawEntries(in: reading)) { entry in
                                LabeledContent(entry.path) {
                                    Text(entry.value)
                                        .textSelection(.enabled)
                                }
                                .font(.callout.monospaced())
                            }
                        }
                    }
                } footer: {
                    Text("Serial numbers are redacted.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 520)
        .toolbar {
            ToolbarItem {
                Button("Copy Report", systemImage: "doc.on.doc", action: copyReport)
                    .disabled(monitor.snapshot == nil)
                    .help("Copy a plain-text report without serial numbers")
            }
        }
        .onAppear {
            monitor.setLiveRefreshInterval(.seconds(2), for: "details")
            NSApp.activate()
        }
        .onDisappear { monitor.setLiveRefreshInterval(nil, for: "details") }
    }

    private func rawEntries(in reading: BatteryReading) -> [RawEntry] {
        let entries = RawEntry.flatten(reading.redactedRawCapture)
        let filter = rawFilter.trimmingCharacters(in: .whitespaces)
        guard !filter.isEmpty else { return entries }
        return entries.filter {
            $0.path.localizedCaseInsensitiveContains(filter) || $0.value.localizedCaseInsensitiveContains(filter)
        }
    }

    private func copyReport() {
        guard let snapshot = monitor.snapshot else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(BatteryReport.text(for: snapshot), forType: .string)
    }
}
#endif

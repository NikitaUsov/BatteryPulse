#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI
import UniformTypeIdentifiers

/// Everything behind the numbers, for the curious: gauge details and the raw dictionaries macOS
/// reports. Hidden unless enabled in Settings → Advanced.
struct DeveloperView: View {
    let monitor: BatteryMonitor
    @State private var filter = ""
    private let formatter = BatteryFormatter.app

    var body: some View {
        List {
            if let snapshot = monitor.snapshot {
                gaugeSection(snapshot)
            }
            if let reading = monitor.reading {
                let capture = reading.redactedRawCapture
                rawSection("AppleSmartBattery", capture[BatteryReading.CaptureKey.smartBattery])
                rawSection("IOPowerSources", capture[BatteryReading.CaptureKey.powerSource])
                rawSection("IOPSCopyExternalPowerAdapterDetails", capture[BatteryReading.CaptureKey.adapterDetails])
            }
        }
        .searchable(text: $filter, placement: .toolbar, prompt: "Filter keys and values")
        .toolbar {
            ToolbarItemGroup {
                Button("Copy JSON", systemImage: "curlybraces", action: copyJSON)
                    .help("Copy the parsed readings as JSON, without serial numbers")
                Button("Export Capture…", systemImage: "square.and.arrow.up", action: exportCapture)
                    .help("Save the raw data for a bug report. Serial numbers are redacted.")
            }
        }
        .disabled(monitor.reading == nil)
    }

    private func gaugeSection(_ s: BatterySnapshot) -> some View {
        Section("Gauge") {
            if let updated = s.gaugeUpdatedAt {
                ValueRow("Last gauge update", updated.formatted(date: .omitted, time: .standard))
            }
            if let hardware = s.hardwareChargePercent {
                ValueRow("Gauge charge", formatter.percent(hardware, fractionDigits: 1))
            }
            if let instant = s.instantAmperageMA {
                ValueRow("Instant current", formatter.milliamps(instant, signed: true))
            }
            if let reason = s.notChargingReason {
                ValueRow("Not charging reason", hex(reason))
            }
            if let reason = s.slowChargingReason {
                ValueRow("Slow charging reason", hex(reason))
            }
            if let failure = s.permanentFailureStatus {
                ValueRow("Permanent failure status", hex(failure))
            }
        }
    }

    @ViewBuilder
    private func rawSection(_ title: String, _ value: PropertyValue?) -> some View {
        if let dictionary = value?.dictionaryValue, !dictionary.isEmpty {
            let entries = filtered(RawEntry.flatten(dictionary))
            if !entries.isEmpty {
                Section {
                    ForEach(entries) { entry in
                        LabeledContent {
                            Text(entry.value)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Text(verbatim: entry.path)
                                .textSelection(.enabled)
                        }
                        .font(.callout.monospaced())
                    }
                } header: {
                    Text(verbatim: title)
                } footer: {
                    Text("Serial numbers are redacted.")
                }
            }
        }
    }

    private func filtered(_ entries: [RawEntry]) -> [RawEntry] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.path.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query)
        }
    }

    private func hex(_ value: Int) -> String {
        "0x" + String(value, radix: 16, uppercase: true)
    }

    private func copyJSON() {
        guard var snapshot = monitor.snapshot else { return }
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
        guard let reading = monitor.reading else { return }
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
#endif

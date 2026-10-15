#if os(macOS)
import BatteryCore
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// What History's Export menu exports: the store the page loaded and whose history it is.
struct HistoryExportTarget {
    let store: HistoryStore
    let source: HistoryExportSource
}

/// One pick from the Export menu; a new id each time, so the same item picked twice exports twice.
struct HistoryExportRequest: Equatable {
    let kind: HistoryExportKind
    let id = UUID()
}

/// A finished export for the system's Save panel. The panel asks for one content type, and the
/// representation of that type hands over the bytes.
struct HistoryExportFile: Transferable {
    let kind: HistoryExportKind
    let data: Data
    let fileName: String

    var contentType: UTType { kind == .json ? .json : .commaSeparatedText }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in file.data }
        DataRepresentation(exportedContentType: .json) { file in file.data }
    }
}

/// History's Export menu. It only records the pick; ``HistoryExporter`` on the page does the
/// rest, because presentations attached inside toolbar items are unreliable on macOS.
struct HistoryExportMenu: View {
    @Binding var request: HistoryExportRequest?
    var isEnabled: Bool

    var body: some View {
        Menu {
            Section {
                Button("Readings by Minute…") { request = HistoryExportRequest(kind: .samplesCSV) }
                Button("Battery Health by Day…") { request = HistoryExportRequest(kind: .daysCSV) }
            } header: {
                Text(verbatim: "CSV")
            }
            Section {
                Button("All History…") { request = HistoryExportRequest(kind: .json) }
            } header: {
                Text(verbatim: "JSON")
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .help("Save the recorded history as a CSV or JSON file")
        // Off while a file is being prepared.
        .disabled(!isEnabled || request != nil)
    }
}

/// Builds the requested file off the main actor, shows the Save panel, and reports a failure.
/// Nothing runs until a request arrives.
struct HistoryExporter: ViewModifier {
    @Binding var request: HistoryExportRequest?
    let target: HistoryExportTarget?
    @State private var file: HistoryExportFile?
    @State private var isPresented = false
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            // Cancelled when the page goes away; a cancelled preparation shows nothing.
            .task(id: request?.id) { await prepare() }
            .fileExporter(
                isPresented: $isPresented, item: file, contentTypes: [file?.contentType ?? .json],
                defaultFilename: file?.fileName,
                onCompletion: { result in
                    if case .failure(let error) = result { failure = error.localizedDescription }
                    file = nil
                },
                onCancellation: { file = nil }
            )
            .alert(Text("Couldn't Export History"), isPresented: failureShown) {
                Button("OK") {}
            } message: {
                Text(verbatim: failure ?? "")
            }
    }

    private var failureShown: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    private func prepare() async {
        guard let request else { return }
        defer { self.request = nil }
        guard let target else { return }
        let now = Date()
        let info = HistoryExportInfo(exportedAt: now, generator: AppInfo.generator, source: target.source)
        do {
            // The region's number format at the moment of export picks the spreadsheet dialect,
            // so a change in System Settings applies without a relaunch.
            let data = try await HistoryExport.data(
                request.kind, from: target.store, dialect: .preferred(for: .autoupdatingCurrent), info: info,
                timeZone: .autoupdatingCurrent)
            guard !Task.isCancelled else { return }
            file = HistoryExportFile(
                kind: request.kind, data: data,
                fileName: HistoryExport.fileName(
                    request.kind, source: target.source, date: now, timeZone: .autoupdatingCurrent))
            // Only once the file is ready, in the same main-actor turn.
            isPresented = true
        } catch {
            guard !Task.isCancelled else { return }
            failure = error.localizedDescription
        }
    }
}

extension AppInfo {
    /// The JSON export's `generator`: "BatteryPulse 0.6.0 (12)", or "BatteryPulse" for a build
    /// without a version.
    static var generator: String { version.map { "BatteryPulse \($0)" } ?? "BatteryPulse" }
}
#endif

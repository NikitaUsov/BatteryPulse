#if os(macOS)
import AppIntents
import Foundation
import SwiftUI
import WidgetKit
import os

// W0-1 (docs/plans/0.6.2/PLAN.md, WP-W0), spike branch only: the App Intents pieces whose metadata
// `scripts/build-app.sh` extracts by hand and CI checks, in a test kind of their own, so the
// battery widget stays 0.6.1's. Session A reads their log lines:
// - (a) `SpikeWidgetIntent.details`, an array sized per widget family. An `AppEnum` array can't
//   be: Xcode 27.1's SDK (macOS 27.0) has the per-family `size:` initializers only for values
//   that are an `AppEntity`, a `FileEntity`, an `IntentPerson` or a system value type, so each
//   detail is an entity (`SpikeDetail`) whose query lists the cases of `SpikeField`;
// - (b) `SpikeWidgetIntent.device`, an `AppEntity` whose `EntityQuery` logs each run;
// - (c) `SpikeRefreshIntent`, a `Button(intent:)` whose perform logs its process; the timeline
//   logs every call, so a reload after the perform shows;
// - (d) one `ParameterSummary` with a parameter (`mainValue`, an `AppEnum`), and
//   `SpikeField.caseDisplayRepresentations`.

/// The test kind's identifier.
enum SpikeWidgetKind {
    static let spike = "io.github.nikitausov.BatteryPulse.spike"
}

/// The spike's lines in the `widget` category: static text, numbers and case names only.
private let spikeLog = Logger(subsystem: "io.github.nikitausov.BatteryPulse", category: "widget")

/// The process that runs a perform or a query, as a case name for the log.
enum SpikeProcess: String {
    case widgetExtension
    case app
    case other

    static var current: SpikeProcess {
        switch Bundle.main.bundleIdentifier {
        case "io.github.nikitausov.BatteryPulse.Widget": .widgetExtension
        case "io.github.nikitausov.BatteryPulse": .app
        default: .other
        }
    }
}

/// (d): the main value's choices, with one display representation per case; the details of (a)
/// show them too.
enum SpikeField: String, AppEnum {
    case charge
    case maximumCapacity
    case temperature
    case cycleCount

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Details")
    }

    static var caseDisplayRepresentations: [SpikeField: DisplayRepresentation] {
        [
            .charge: "Charge",
            .maximumCapacity: "Maximum capacity",
            .temperature: "Temperature",
            .cycleCount: "Cycle count",
        ]
    }
}

/// (a): one detail of the per-family sized array, identified by its field's raw value.
struct SpikeDetail: AppEntity {
    let field: SpikeField

    var id: String {
        field.rawValue
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Details")
    }

    static var defaultQuery: SpikeDetailQuery {
        SpikeDetailQuery()
    }

    var displayRepresentation: DisplayRepresentation {
        SpikeField.caseDisplayRepresentations[field]
            ?? DisplayRepresentation(title: LocalizedStringResource(stringLiteral: field.rawValue))
    }
}

/// (a): every field, in the extension like ``SpikeDeviceQuery``.
struct SpikeDetailQuery: EntityQuery {
    static var allowedExecutionTargets: IntentExecutionTargets {
        .widgetKitExtension
    }

    func entities(for identifiers: [String]) async throws -> [SpikeDetail] {
        let found = identifiers.compactMap { SpikeField(rawValue: $0).map(SpikeDetail.init(field:)) }
        spikeLog.notice(
            "spike query details asked=\(identifiers.count, privacy: .public) found=\(found.count, privacy: .public) process=\(SpikeProcess.current.rawValue, privacy: .public)"
        )
        return found
    }

    func suggestedEntities() async throws -> [SpikeDetail] {
        spikeLog.notice(
            "spike query details suggested process=\(SpikeProcess.current.rawValue, privacy: .public)"
        )
        return SpikeField.allCases.map(SpikeDetail.init(field:))
    }
}

/// (b): an entity the edit sheet offers through ``SpikeDeviceQuery``.
struct SpikeDevice: AppEntity {
    let id: String
    let name: String

    static let all = [
        SpikeDevice(id: "spike-1", name: "Spike device 1"),
        SpikeDevice(id: "spike-2", name: "Spike device 2"),
    ]

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Device")
    }

    static var defaultQuery: SpikeDeviceQuery {
        SpikeDeviceQuery()
    }

    /// The name as it is, not a catalog key.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

/// (b): logs each run with the process it runs in. Kept in the widget extension, as 0.7's device
/// query will be (§8.5).
struct SpikeDeviceQuery: EntityQuery {
    static var allowedExecutionTargets: IntentExecutionTargets {
        .widgetKitExtension
    }

    func entities(for identifiers: [String]) async throws -> [SpikeDevice] {
        let found = SpikeDevice.all.filter { identifiers.contains($0.id) }
        spikeLog.notice(
            "spike query devices asked=\(identifiers.count, privacy: .public) found=\(found.count, privacy: .public) process=\(SpikeProcess.current.rawValue, privacy: .public)"
        )
        return found
    }

    func suggestedEntities() async throws -> [SpikeDevice] {
        spikeLog.notice(
            "spike query devices suggested process=\(SpikeProcess.current.rawValue, privacy: .public)"
        )
        return SpikeDevice.all
    }
}

/// The test kind's configuration: (a), (b) and (d).
struct SpikeWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource {
        "Battery"
    }

    @Parameter(title: "Main value", default: .charge)
    var mainValue: SpikeField

    @Parameter(title: "Details", size: [.systemSmall: 1, .systemMedium: 4, .systemLarge: 8, .systemExtraLarge: 12])
    var details: [SpikeDetail]?

    @Parameter(title: "Device")
    var device: SpikeDevice?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$mainValue)") {
            \.$details
            \.$device
        }
    }
}

/// (c): the button's intent. It only logs; WidgetKit reloads the timeline after a perform.
struct SpikeRefreshIntent: AppIntent {
    static var title: LocalizedStringResource {
        "Refresh"
    }

    static var isDiscoverable: Bool {
        false
    }

    func perform() async throws -> some IntentResult {
        spikeLog.notice(
            "spike perform refresh process=\(SpikeProcess.current.rawValue, privacy: .public) pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public)"
        )
        return .result()
    }
}

struct SpikeEntry: TimelineEntry {
    let date: Date
    let mainValue: SpikeField
    let detailCount: Int
    let deviceName: String?
}

/// One entry and no reload of its own, so each `timeline` line follows a configuration change or
/// a perform.
struct SpikeTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SpikeEntry {
        SpikeEntry(date: .now, mainValue: .charge, detailCount: 0, deviceName: nil)
    }

    func snapshot(for configuration: SpikeWidgetIntent, in context: Context) async -> SpikeEntry {
        Self.entry(for: configuration)
    }

    func timeline(for configuration: SpikeWidgetIntent, in context: Context) async -> Timeline<SpikeEntry> {
        let entry = Self.entry(for: configuration)
        let device = entry.deviceName == nil ? "none" : "chosen"
        spikeLog.notice(
            "spike timeline family=\(Self.name(of: context.family), privacy: .public) main=\(entry.mainValue.rawValue, privacy: .public) details=\(entry.detailCount, privacy: .public) device=\(device, privacy: .public) process=\(SpikeProcess.current.rawValue, privacy: .public)"
        )
        return Timeline(entries: [entry], policy: .never)
    }

    private static func entry(for configuration: SpikeWidgetIntent) -> SpikeEntry {
        SpikeEntry(
            date: .now, mainValue: configuration.mainValue, detailCount: configuration.details?.count ?? 0,
            deviceName: configuration.device?.name)
    }

    private static func name(of family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: "small"
        case .systemMedium: "medium"
        case .systemLarge: "large"
        case .systemExtraLarge: "extraLarge"
        default: "other"
        }
    }
}

struct SpikeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: SpikeWidgetKind.spike, intent: SpikeWidgetIntent.self, provider: SpikeTimelineProvider()
        ) { entry in
            SpikeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Test widget")
        .description("Shows the chosen details and device.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

/// The main value's case, the detail count, the device and the time of the render, so a reload
/// after Refresh shows.
struct SpikeWidgetView: View {
    let entry: SpikeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "W0-1 · \(entry.mainValue.rawValue) · \(entry.detailCount) · \(entry.deviceName ?? "-")")
                .font(.caption)
            Text(entry.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(intent: SpikeRefreshIntent()) {
                Text("Refresh")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif

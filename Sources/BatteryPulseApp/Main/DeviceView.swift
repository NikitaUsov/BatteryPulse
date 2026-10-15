#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI

/// The page of one iPhone or iPad: its charge, maximum capacity and cycles, capacities and
/// details, built from the Overview's cards.
///
/// Values come from this session's read, else from the remembered device; nothing on the page
/// ticks. Motion keys on ``BatteryMotionKey`` and on whether a problem shows, never on the entry
/// or the battery themselves.
struct DeviceView: View {
    let entry: IDeviceEntry
    /// Opens History with this device as its source.
    let showInHistory: @MainActor (DeviceKey) -> Void
    @Environment(IDeviceMonitor.self) private var devices
    @Environment(\.motion) private var motion
    @State private var confirmsForgetting = false
    private let formatter = BatteryFormatter.app

    /// Demo Mode's simulated iPhone: nothing is read, forgotten or reported.
    private var isDemo: Bool { entry.id == .demo }

    var body: some View {
        let key = BatteryMotionKey(device: entry.battery)
        let problem = shownProblem
        ScrollView {
            CardGroup {
                VStack(spacing: 16) {
                    if let battery = entry.battery {
                        hero(battery)
                        if let problem { problemCard(problem) }
                        gauges(battery)
                        if battery.currentCapacityMAh != nil || battery.designCapacityMAh != nil {
                            Card("Capacity") {
                                CapacityBars(
                                    bars: CapacityBar.bars(
                                        remainingMAh: battery.currentCapacityMAh,
                                        fullChargeMAh: battery.fullChargeCapacityMAh,
                                        designMAh: battery.designCapacityMAh),
                                    formatter: formatter)
                            }
                        }
                        details(battery)
                    } else if let problem {
                        // Never read: the problem stands alone.
                        problemCard(problem)
                    } else if entry.isReading {
                        ProgressView {
                            Text("Reading…")
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                    if !devices.isEnabled, !isDemo { offFooter }
                }
            }
            // A new charge state or a problem appearing changes the cards' heights: the page moves
            // as one, once per event. Under Reduce Motion the cards snap and the problem fades.
            .animation(motion.change, value: key)
            .animation(motion.change, value: problem != nil)
            .padding(20)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { devices.read(entry.id) }
                    .disabled(isDemo || entry.connection == nil || entry.isReading || !devices.isEnabled)
                    .help(refreshHelp)
            }
            ToolbarItem(placement: .primaryAction) {
                // A Label, not Menu("…"): the catalog test finds the title in a Label.
                Menu {
                    Button("Show in History") { showInHistory(entry.id) }
                        .disabled(isDemo || !entry.isRemembered)
                    Button("Forget This Device…") { confirmsForgetting = true }
                        .disabled(isDemo)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Forget “\(DeviceText.nameForSentence(entry))”?", isPresented: $confirmsForgetting) {
            Button("Forget Device", role: .destructive) {
                Task { await devices.forget(entry.id) }
            }
        } message: {
            Text("BatteryPulse removes the device and its battery history from this Mac.")
        }
        // Reads every minute while the page can be seen. Hiding clears only this device: the
        // page switched away from disappears after the new one appeared.
        .task(id: motion.isVisible) {
            guard !isDemo else { return }
            devices.setPageVisible(entry.id, motion.isVisible)
            if motion.isVisible { devices.listIfStale() }
        }
        .onDisappear {
            if !isDemo { devices.setPageVisible(entry.id, false) }
        }
    }

    // MARK: - Hero

    private func hero(_ battery: IDeviceBattery) -> some View {
        let tint = BatteryPresentation.levelTier(percent: battery.chargePercent, state: battery.chargeState).color
        return Card {
            HStack(spacing: 24) {
                BatteryGlyph(
                    level: (battery.chargePercent ?? 0) / 100,
                    isCharging: battery.chargeState == .charging,
                    tint: tint
                )
                .frame(width: 132)
                VStack(alignment: .leading, spacing: 4) {
                    Text(battery.chargePercent.map { formatter.percent($0) } ?? "—")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .numericValue(battery.chargePercent)
                    Text(statePhrase(battery))
                        .font(.title3)
                    Text(verbatim: subtitle)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        timeLine
                            .foregroundStyle(.secondary)
                        if entry.isReading {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel(Text("Reading…"))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// "Charging at 8.7 W" while the battery takes power, else the state.
    private func statePhrase(_ battery: IDeviceBattery) -> String {
        if battery.chargeState == .charging, let watts = battery.batteryPowerWatts,
            watts >= BatteryPresentation.powerFlowDeadBandWatts
        {
            return String(localized: "Charging at \(formatter.watts(watts))")
        }
        return Phrases.state(battery.chargeState)
    }

    /// "iPhone 17 Pro Max · iOS 27.0.1 · Connected by cable": data and one localized phrase.
    private var subtitle: String {
        var parts: [String] = []
        if let model = DeviceText.model(entry) { parts.append(model) }
        if let version = entry.osVersion { parts.append("\(entry.osName) \(version)") }
        parts.append(connectionPhrase)
        return parts.joined(separator: " · ")
    }

    private var connectionPhrase: String {
        switch entry.connection {
        case .usb?: String(localized: "Connected by cable")
        case .wifi?, .unknown?: String(localized: "Connected over Wi-Fi")
        case nil: String(localized: "Not connected")
        }
    }

    /// When the values were read, or when the device was last seen. Absolute times: nothing ticks.
    @ViewBuilder
    private var timeLine: some View {
        if entry.connection != nil, let readAt = entry.readAt {
            Text("Updated \(DeviceText.date(readAt))")
        } else if entry.connection == nil, let lastSeen = entry.lastSeen {
            Text("Last seen \(DeviceText.date(lastSeen))")
        }
    }

    // MARK: - Gauges

    private func gauges(_ battery: IDeviceBattery) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let percent = battery.chargePercent {
                GaugeTile(
                    title: "Charge",
                    fraction: percent / 100,
                    value: formatter.percent(percent),
                    number: percent,
                    caption: chargeCaption(battery),
                    tint: BatteryPresentation.levelTier(percent: percent, state: battery.chargeState).color
                )
            }
            if let health = battery.maximumCapacityPercent {
                let tier = BatteryPresentation.healthTier(device: battery)
                GaugeTile(
                    title: "Maximum capacity",
                    fraction: health / 100,
                    value: formatter.percent(health),
                    number: health,
                    caption: condition(tier),
                    tint: tier.color
                )
            }
            if let cycles = battery.cycleCount {
                // The gauge's own rating wins over Apple's published one for the model.
                let rated =
                    battery.designCycleCount
                    ?? IDeviceModel.ratedCycles(productType: entry.productType, deviceClass: entry.deviceClass) ?? 1000
                GaugeTile(
                    title: "Cycle count",
                    fraction: Double(cycles) / Double(rated),
                    value: cycles.formatted(),
                    number: Double(cycles),
                    caption: String(localized: "of \(rated.formatted()) rated"),
                    tint: .blue
                )
            }
        }
        // Tiles share the tallest tile's height.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// "3,151 of 4,922 mAh".
    private func chargeCaption(_ battery: IDeviceBattery) -> String? {
        guard let current = battery.currentCapacityMAh, let full = battery.fullChargeCapacityMAh else { return nil }
        return String(localized: "\(current.formatted()) of \(formatter.milliampHours(full))")
    }

    private func condition(_ tier: BatteryPresentation.LevelTier) -> String {
        switch tier {
        case .normal: String(localized: "Normal", comment: "Battery condition")
        case .low: String(localized: "Service Recommended", comment: "Battery condition")
        case .critical: String(localized: "Check Battery", comment: "Battery condition")
        }
    }

    // MARK: - Details

    private func details(_ battery: IDeviceBattery) -> some View {
        Card("Details") {
            VStack(alignment: .leading, spacing: 8) {
                if let model = DeviceText.model(entry) {
                    ValueRow("Model", model)
                        .help(Text(verbatim: entry.productType ?? model))
                }
                if let version = entry.osVersion {
                    ValueRow("Software Version", "\(entry.osName) \(version)")
                }
                ValueRow("Connection", connectionPhrase)
                if let nominal = battery.nominalChargeCapacityMAh {
                    ValueRow("Nominal full charge", capacity(nominal, ratio: battery.nominalToDesignPercent))
                }
                if let full = battery.fullChargeCapacityMAh {
                    ValueRow("Full charge capacity", capacity(full, ratio: battery.fullChargeToDesignPercent))
                }
                if let design = battery.designCapacityMAh {
                    ValueRow("Design capacity", formatter.milliampHours(design))
                }
                if let celsius = battery.temperatureCelsius {
                    ValueRow("Temperature", formatter.celsius(celsius))
                }
                if let millivolts = battery.voltageMV {
                    ValueRow("Voltage", formatter.volts(millivolts: millivolts))
                }
                if let milliamps = battery.amperageMA {
                    ValueRow("Current", formatter.milliamps(milliamps, signed: true))
                }
                if let watts = battery.batteryPowerWatts {
                    ValueRow("Battery power", formatter.watts(watts, signed: true))
                }
                if let adapter = battery.adapter {
                    ValueRow("Adapter", adapterDescription(adapter))
                }
                if let firstUse = battery.firstUseDate {
                    // The month, as iOS Settings shows it, from the date the device stores in UTC.
                    ValueRow("First use", firstUse.formatted(Date.FormatStyle(timeZone: .gmt).month(.wide).year()))
                }
            }
        }
    }

    /// "4,800 mAh  95.4 % of design".
    private func capacity(_ milliampHours: Int, ratio: Double?) -> String {
        let value = formatter.milliampHours(milliampHours)
        guard let ratio else { return value }
        return value + "  " + String(localized: "\(formatter.percent(ratio, fractionDigits: 1)) of design")
    }

    /// "20 W · pd charger", or "Wireless charger".
    private func adapterDescription(_ adapter: PowerAdapter) -> String {
        var parts: [String] = []
        if let watts = adapter.watts { parts.append(formatter.watts(Double(watts), fractionDigits: 0)) }
        if adapter.isWireless == true {
            parts.append(String(localized: "Wireless charger"))
        } else if let name = adapter.name ?? adapter.adapterDescription, !name.isEmpty {
            parts.append(name)
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    // MARK: - Problem and footer

    private struct ShownProblem: Equatable {
        var text: String
        var canRetry: Bool
    }

    /// What keeps the page from being current, if anything.
    private var shownProblem: ShownProblem? {
        guard devices.isEnabled, !isDemo else { return nil }
        if let unavailable = devices.unavailable {
            if case .frameworkUnavailable = unavailable {
                return ShownProblem(text: Phrases.deviceUnavailable(unavailable), canRetry: false)
            }
            return ShownProblem(text: Phrases.deviceUnavailable(unavailable), canRetry: true)
        }
        let name = DeviceText.nameForSentence(entry)
        if let problem = entry.problem {
            return ShownProblem(
                text: Phrases.deviceProblem(problem, name: name, connection: entry.connection), canRetry: true)
        }
        // A call timed out: automatic reads wait for Try Again.
        if devices.isStalled, entry.connection != nil {
            return ShownProblem(
                text: Phrases.deviceProblem(.transportFailed(.timedOut), name: name, connection: entry.connection),
                canRetry: true)
        }
        return nil
    }

    private func problemCard(_ problem: ShownProblem) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(problem.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if problem.canRetry {
                    Button("Try Again") { devices.read(entry.id) }
                        .disabled(entry.isReading)
                }
            }
        }
        .transition(motion.fadeTransition)
    }

    private var offFooter: some View {
        HStack {
            Text("Reading iPhone and iPad batteries is off.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Turn On") { AppDevices.setReading(true) }
        }
        .padding(.horizontal, 4)
    }

    private var refreshHelp: Text {
        if isDemo { return Text("Not available in Demo Mode") }
        if entry.connection == nil { return Text("Connect the device by cable to read it") }
        return Text("Read the battery again")
    }
}
#endif

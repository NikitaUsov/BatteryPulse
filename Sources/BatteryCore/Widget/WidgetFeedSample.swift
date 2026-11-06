import Foundation

extension WidgetFeed {
    /// A made-up feed written at `now`, for the widget gallery and the CI previews, so neither
    /// needs a feed: a day that ran on battery, slept, charged on the adapter to full and ran on
    /// battery again; a week of such days; 90 days of a slowly wearing battery; an iPhone read a
    /// few minutes ago and an iPad read the day before, named by their models. No one's own data.
    public static func sample(at now: Date) -> WidgetFeed {
        let writtenAt = wholeSeconds(now)
        let day = sampleSeries(.day, at: writtenAt) { index in
            switch index {
            case 0..<16: SampleStep(percent: 78 - index, watts: -7.5, celsius: 30.5, plugged: false)
            // Asleep: a gap.
            case 16..<32: nil
            case 32..<44:
                SampleStep(
                    percent: 62 + 3 * (index - 32), watts: 28 - 2 * Double(index - 32), celsius: 33, plugged: true)
            case 44..<56: SampleStep(percent: 100, watts: 0, celsius: 31, plugged: true)
            default:
                SampleStep(
                    percent: 100 - (index - 56) * 6 / 5, watts: -8 - Double(index % 3),
                    celsius: 30 + Double(index % 4) / 2,
                    plugged: false)
            }
        }
        let week = sampleSeries(.week, at: writtenAt) { index in
            let hour = index % 12
            // The third day, BatteryPulse didn't run.
            guard index / 12 != 2 else { return nil }
            return hour < 4
                ? SampleStep(percent: 40 + 15 * hour, watts: 24 - 4 * Double(hour), celsius: 32, plugged: true)
                : SampleStep(percent: 100 - 7 * (hour - 4), watts: -7 - Double(hour % 2), celsius: 30, plugged: false)
        }
        let calendar = HistoryDay.gregorian(in: .gmt)
        let firstDay = calendar.date(byAdding: .day, value: -(maximumDays - 1), to: writtenAt) ?? writtenAt
        let days = 0..<maximumDays
        return WidgetFeed(
            writtenAt: writtenAt, languages: ["en"], recordsHistory: true, readsDevices: true, day: day, week: week,
            statistics24h: Statistics(
                averageDrainPercentPerHour: 6.4, timeOnBattery: 14 * 60 * 60, chargingSessions: 1),
            onBatterySince: day.date(ofStep: 56),
            daily: Daily(
                firstDay: HistoryDay.key(for: firstDay, calendar: calendar),
                capacityToDesign10: days.map { 1_003 - $0 * 28 / (maximumDays - 1) },
                cycleCount: days.map { 92 + $0 * 39 / (maximumDays - 1) }),
            devices: sampleDevices(at: writtenAt))
    }

    /// Demo Mode's iPhone (``DemoDevice``), read four minutes before `now`, and an iPad read the
    /// day before, under made-up keys: never ``DeviceKey/demo``, which the feed refuses.
    static func sampleDevices(at now: Date) -> [Device] {
        let phone = DemoDevice.battery
        return [
            Device(
                key: sampleKey("1"), model: "iPhone 17 Pro Max", deviceClass: "iPhone",
                percent: phone.chargePercent.map { Int($0.rounded()) }, state: phone.chargeState,
                maximumCapacity: phone.maximumCapacityPercent.map { Int($0.rounded()) }, cycleCount: phone.cycleCount,
                temperature10: phone.temperatureCelsius.map { Int(($0 * 10).rounded()) },
                readAt: now.addingTimeInterval(-4 * 60)),
            Device(
                key: sampleKey("2"), model: "iPad Air", deviceClass: "iPad", percent: 18, state: .discharging,
                maximumCapacity: 97, cycleCount: 64, temperature10: 291, readAt: now.addingTimeInterval(-26 * 60 * 60)),
        ]
    }

    /// A key of 32 hexadecimal characters that ends in `last`, as a real one is long.
    static func sampleKey(_ last: Character) -> DeviceKey {
        DeviceKey(rawValue: String(repeating: "0", count: 31) + String(last)) ?? .demo
    }

    /// One step of a sample series.
    private struct SampleStep {
        var percent: Int
        var watts: Double
        var celsius: Double
        var plugged: Bool
    }

    /// The period's steps up to the one that holds `now`, each from `step(index)`.
    private static func sampleSeries(_ period: Period, at now: Date, _ step: (Int) -> SampleStep?) -> Series {
        let steps = (0..<period.count).map(step)
        return Series(
            start: seriesStart(period, at: now), step: period.step, percent: steps.map { $0?.percent },
            batteryWatts10: steps.map { $0.map { Int(($0.watts * 10).rounded()) } },
            temperature10: steps.map { $0.map { Int(($0.celsius * 10).rounded()) } }, plugged: steps.map { $0?.plugged }
        )
    }
}

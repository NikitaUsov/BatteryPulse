import Foundation
import Testing

@testable import BatteryCore

@Suite struct HistoryExportTests {
    private let moscow = TimeZone(identifier: "Europe/Moscow")!
    /// 2026-10-14 10:25:00 UTC = 13:25 in Moscow.
    private let start = Date(timeIntervalSince1970: 1_791_973_500)

    private var samples: [HistorySample] {
        [
            HistorySample(
                time: start, event: .launch, percent: 84, state: .discharging, isExternalPowerConnected: false,
                batteryWatts: -5.214, systemLoadWatts: 6.3, temperatureCelsius: 31.24, remainingMAh: 3900,
                fullChargeMAh: 4620),
            HistorySample(time: start.addingTimeInterval(60), percent: nil, state: .unknown),
            HistorySample(
                time: start.addingTimeInterval(120), percent: 83.5, state: .charging, isExternalPowerConnected: true,
                batteryWatts: 12.5, systemLoadWatts: -0.004, temperatureCelsius: 30, remainingMAh: 3880,
                fullChargeMAh: 4620),
        ]
    }

    private var days: [HistoryDay] {
        [
            HistoryDay(
                day: "2026-10-13", healthPercent: 100, capacityToDesignPercent: 101.3, nominalChargeCapacityMAh: 4757,
                fullChargeCapacityMAh: 4620, cycleCount: 12),
            HistoryDay(day: "2026-10-14"),
        ]
    }

    private func text(
        _ kind: HistoryExportKind, _ dialect: CSVDialect = .standard, source: HistoryExportSource? = nil
    ) -> String {
        let info = HistoryExportInfo(exportedAt: start.addingTimeInterval(3600), generator: "bpulse", source: source)
        let data = HistoryExport.data(
            kind, samples: samples, days: days, dialect: dialect, info: info, timeZone: moscow)
        return String(decoding: data, as: UTF8.self)
    }

    @Test func numbersAreLocaleIndependentAndTrimmed() {
        func number(_ value: Double?, _ digits: Int, _ decimal: UInt8 = 0x2E) -> String {
            var buffer = ExportBuffer()
            buffer.appendNumber(value, fractionDigits: digits, decimal: decimal)
            return String(decoding: buffer.bytes, as: UTF8.self)
        }
        #expect(number(-5.214, 2) == "-5.21")
        #expect(number(12.5, 1) == "12.5")
        #expect(number(12.5, 1, 0x2C) == "12,5")
        #expect(number(100, 2) == "100")
        #expect(number(-0.004, 2) == "0")
        #expect(number(0.05, 2) == "0.05")
        #expect(number(1.005, 1) == "1")
        #expect(number(-12, 2) == "-12")
        #expect(number(0.1, 2) == "0.1")
        #expect(number(nil, 2) == "")
        #expect(number(.nan, 2) == "")
        #expect(number(.infinity, 2) == "")
    }

    @Test func timesMatchFoundationAcrossTimeZonesAndDaylightSaving() throws {
        let zones = ["UTC", "Europe/Moscow", "America/New_York", "Europe/Berlin", "Asia/Kolkata", "Pacific/Chatham"]
        for identifier in zones {
            let zone = try #require(TimeZone(identifier: identifier))
            let iso = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: zone)
            let local = Date.ISO8601FormatStyle(dateTimeSeparator: .space, timeZone: zone)
                .year().month().day().time(includingFractionalSeconds: false)
            // Every 61 minutes through 2026 and 2028 (a leap year), so every hour of the day
            // and both daylight-saving switches are crossed.
            for year in [1_767_225_600.0, 1_830_297_600.0] {
                var time = year
                while time < year + 366 * 86_400 {
                    let date = Date(timeIntervalSince1970: time)
                    var buffer = ExportBuffer()
                    let offset = zone.secondsFromGMT(for: date)
                    buffer.appendTime(date, offset: offset, iso: true)
                    buffer.append(ascii: 0x7C)
                    buffer.appendTime(date, offset: offset, iso: false)
                    let written = String(decoding: buffer.bytes, as: UTF8.self)
                    #expect(written == date.formatted(iso) + "|" + date.formatted(local), "\(identifier) \(time)")
                    time += 61 * 60
                }
            }
        }
        // A damaged record with a time far beyond any calendar leaves the field empty instead of
        // crashing the export.
        var buffer = ExportBuffer()
        buffer.appendTime(Date(timeIntervalSince1970: 1e300), offset: 0, iso: true)
        buffer.appendTime(Date(timeIntervalSince1970: -1e300), offset: 3600, iso: false)
        #expect(buffer.bytes.isEmpty)
    }

    @Test func dialectFollowsTheDecimalSeparator() {
        for identifier in ["ru_RU", "de_DE", "fr_FR", "uk_UA"] {
            #expect(CSVDialect.preferred(for: Locale(identifier: identifier)) == .decimalComma, "\(identifier)")
        }
        for identifier in ["en_US", "en_GB", "ja_JP", "de_CH", "zh_CN"] {
            #expect(CSVDialect.preferred(for: Locale(identifier: identifier)) == .standard, "\(identifier)")
        }
    }

    @Test func samplesCSV() {
        #expect(
            text(.samplesCSV) == """
                time,localTime,event,chargePercent,chargeState,isExternalPowerConnected,batteryWatts,systemLoadWatts,temperatureCelsius,remainingMAh,fullChargeMAh\r
                2026-10-14T13:25:00+03:00,2026-10-14 13:25:00,launch,84,discharging,0,-5.21,6.3,31.2,3900,4620\r
                2026-10-14T13:26:00+03:00,2026-10-14 13:26:00,,,unknown,,,,,,\r
                2026-10-14T13:27:00+03:00,2026-10-14 13:27:00,,83.5,charging,1,12.5,0,30,3880,4620\r

                """)
    }

    @Test func samplesCSVWithDecimalComma() {
        #expect(
            text(.samplesCSV, .decimalComma) == """
                time;localTime;event;chargePercent;chargeState;isExternalPowerConnected;batteryWatts;systemLoadWatts;temperatureCelsius;remainingMAh;fullChargeMAh\r
                2026-10-14T13:25:00+03:00;2026-10-14 13:25:00;launch;84;discharging;0;-5,21;6,3;31,2;3900;4620\r
                2026-10-14T13:26:00+03:00;2026-10-14 13:26:00;;;unknown;;;;;;\r
                2026-10-14T13:27:00+03:00;2026-10-14 13:27:00;;83,5;charging;1;12,5;0;30;3880;4620\r

                """)
    }

    @Test func daysCSV() {
        #expect(
            text(.daysCSV, .decimalComma) == """
                day;healthPercent;capacityToDesignPercent;nominalChargeCapacityMAh;fullChargeCapacityMAh;cycleCount\r
                2026-10-13;100;101,3;4757;4620;12\r
                2026-10-14;;;;;\r

                """)
    }

    @Test func csvIsRectangularASCIIWithoutBOM() {
        for dialect in [CSVDialect.standard, .decimalComma] {
            for (kind, columns) in [(HistoryExportKind.samplesCSV, 11), (.daysCSV, 6)] {
                let csv = text(kind, dialect)
                #expect(csv.utf8.allSatisfy { $0 < 0x80 })
                #expect(csv.hasSuffix("\r\n"))
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: false).dropLast()
                #expect(!lines.contains { $0.contains("\n") || $0.contains("\"") })
                for line in lines {
                    #expect(
                        line.split(separator: dialect.fieldSeparator, omittingEmptySubsequences: false).count == columns
                    )
                }
            }
        }
    }

    @Test func csvFieldsAreQuotedOnlyWhenNeeded() {
        var buffer = ExportBuffer()
        for field in ["plain", "a,b", "say \"hi\"", "two\r\nlines", "a;b"] {
            buffer.appendCSVField(field, separator: 0x2C)
            buffer.append(ascii: 0x7C)
        }
        let written = String(decoding: buffer.bytes, as: UTF8.self)
        #expect(written == "plain|\"a,b\"|\"say \"\"hi\"\"\"|\"two\r\nlines\"|a;b|")
    }

    @Test func json() throws {
        let json = text(.json, source: .mac(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 1)))
        #expect(
            json == """
                {
                  "format": "BatteryPulse history",
                  "formatVersion": 1,
                  "exportedAt": "2026-10-14T14:25:00+03:00",
                  "generator": "bpulse",
                  "source": {"kind": "mac", "productType": null, "modelName": null, "osVersion": "27.0.1"},
                  "units": {"batteryWatts": "W", "capacityToDesignPercent": "%", "chargePercent": "%", "fullChargeCapacityMAh": "mAh", "fullChargeMAh": "mAh", "healthPercent": "%", "nominalChargeCapacityMAh": "mAh", "remainingMAh": "mAh", "systemLoadWatts": "W", "temperatureCelsius": "°C"},
                  "samples": [
                    {"time": "2026-10-14T13:25:00+03:00", "event": "launch", "chargePercent": 84, "chargeState": "discharging", "isExternalPowerConnected": false, "batteryWatts": -5.21, "systemLoadWatts": 6.3, "temperatureCelsius": 31.2, "remainingMAh": 3900, "fullChargeMAh": 4620},
                    {"time": "2026-10-14T13:26:00+03:00", "event": null, "chargePercent": null, "chargeState": "unknown", "isExternalPowerConnected": null, "batteryWatts": null, "systemLoadWatts": null, "temperatureCelsius": null, "remainingMAh": null, "fullChargeMAh": null},
                    {"time": "2026-10-14T13:27:00+03:00", "event": null, "chargePercent": 83.5, "chargeState": "charging", "isExternalPowerConnected": true, "batteryWatts": 12.5, "systemLoadWatts": 0, "temperatureCelsius": 30, "remainingMAh": 3880, "fullChargeMAh": 4620}
                  ],
                  "days": [
                    {"day": "2026-10-13", "healthPercent": 100, "capacityToDesignPercent": 101.3, "nominalChargeCapacityMAh": 4757, "fullChargeCapacityMAh": 4620, "cycleCount": 12},
                    {"day": "2026-10-14", "healthPercent": null, "capacityToDesignPercent": null, "nominalChargeCapacityMAh": null, "fullChargeCapacityMAh": null, "cycleCount": null}
                  ]
                }

                """)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["formatVersion"] as? Int == 1)
        let rows = try #require(object["samples"] as? [[String: Any]])
        #expect(rows.count == 3)
        #expect(rows[0]["batteryWatts"] as? Double == -5.21)
        #expect(rows[1]["chargePercent"] is NSNull)
        #expect(Set(rows[1].keys) == Set(HistoryExport.sampleColumns).subtracting(["localTime"]))
    }

    @Test func jsonEscapesStringsAndWritesAnEmptyHistory() throws {
        let source = HistoryExportSource(kind: .iPhone, modelName: "A \"quoted\"\\name\n\u{1}")
        let json = text(.json, source: source)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let decoded = try #require(object["source"] as? [String: Any])
        #expect(decoded["modelName"] as? String == "A \"quoted\"\\name\n\u{1}")
        #expect(decoded["productType"] is NSNull)
        let empty = String(
            decoding: HistoryExport.data(
                .json, samples: [], days: [], info: HistoryExportInfo(exportedAt: start, generator: nil, source: nil),
                timeZone: moscow),
            as: UTF8.self)
        #expect(
            empty.hasSuffix(
                "\"source\": null,\n  \"units\": {\"batteryWatts\": \"W\", \"capacityToDesignPercent\": \"%\", \"chargePercent\": \"%\", \"fullChargeCapacityMAh\": \"mAh\", \"fullChargeMAh\": \"mAh\", \"healthPercent\": \"%\", \"nominalChargeCapacityMAh\": \"mAh\", \"remainingMAh\": \"mAh\", \"systemLoadWatts\": \"W\", \"temperatureCelsius\": \"°C\"},\n  \"samples\": [],\n  \"days\": []\n}\n"
            ))
        #expect(try JSONSerialization.jsonObject(with: Data(empty.utf8)) is [String: Any])
        #expect(text(.samplesCSV).hasPrefix("time,") && text(.daysCSV).hasPrefix("day,"))
    }

    @Test func deviceSourceCarriesTheModelAndNothingThatIdentifies() {
        let pad = HistoryExportSource.device(
            deviceClass: "iPad", productType: "iPad12,1", modelName: "iPad (9th generation)", osVersion: "27.0.1")
        #expect(
            pad
                == HistoryExportSource(
                    kind: .iPad, productType: "iPad12,1", modelName: "iPad (9th generation)", osVersion: "27.0.1"))
        #expect(
            HistoryExportSource.device(deviceClass: "iPhone", productType: nil, modelName: nil, osVersion: nil).kind
                == .iPhone)
        #expect(
            HistoryExportSource.device(deviceClass: nil, productType: nil, modelName: nil, osVersion: nil).kind
                == .iPhone)
        let json = text(.json, source: pad)
        #expect(
            json.contains(
                "\"source\": {\"kind\": \"iPad\", \"productType\": \"iPad12,1\", \"modelName\": \"iPad (9th generation)\", \"osVersion\": \"27.0.1\"}"
            ))
    }

    @Test func fileNames() {
        let late = Date(timeIntervalSince1970: 1_792_020_600)  // 2026-10-14 23:30 UTC, the 15th in Moscow
        #expect(
            HistoryExport.fileName(.samplesCSV, source: .mac(nil), date: late, timeZone: moscow)
                == "BatteryPulse-Mac-samples-2026-10-15.csv")
        #expect(
            HistoryExport.fileName(.daysCSV, source: .mac(nil), date: late, timeZone: TimeZone(identifier: "UTC")!)
                == "BatteryPulse-Mac-days-2026-10-14.csv")
        let phone = HistoryExportSource(kind: .iPhone, productType: "iPhone18,2", modelName: "iPhone 17 Pro Max")
        #expect(
            HistoryExport.fileName(.json, source: phone, date: late, timeZone: moscow)
                == "BatteryPulse-iPhone-17-Pro-Max-history-2026-10-15.json")
        #expect(
            HistoryExportSource(kind: .iPad, modelName: "iPad (9th generation)").fileNameComponent
                == "iPad-9th-generation")
        // A name that isn't plain ASCII (a localized one, a no-break space), or nothing usable: the kind.
        #expect(HistoryExportSource(kind: .iPad, modelName: "iPad\u{A0}Air").fileNameComponent == "iPad")
        #expect(HistoryExportSource(kind: .iPad, modelName: "/:.").fileNameComponent == "iPad")
        #expect(HistoryExportSource(kind: .iPhone, productType: "iPhone18,2").fileNameComponent == "iPhone")
        #expect(
            HistoryExport.fileName(.json, source: nil, date: late, timeZone: moscow)
                == "BatteryPulse-History-history-2026-10-15.json")
    }

    @Test func versionStrings() {
        #expect(
            HistoryExportSource.mac(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
                .osVersion == "27.0")
        #expect(
            HistoryExportSource.mac(OperatingSystemVersion(majorVersion: 27, minorVersion: 1, patchVersion: 2))
                .osVersion == "27.1.2")
        #expect(HistoryExportSource.mac(nil).osVersion == nil)
    }

    @Test func exportsWhatTheStoreKept() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory, now: { [start] in start.addingTimeInterval(86_400) })
        for sample in samples { try await store.record(sample) }
        try await store.record(days[0], at: start)
        let info = HistoryExportInfo(exportedAt: start, generator: nil, source: nil)
        let data = try await HistoryExport.data(.json, from: store, info: info, timeZone: moscow)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        // A minute apart, so the store keeps all three.
        #expect((object["samples"] as? [Any])?.count == 3)
        #expect((object["days"] as? [Any])?.count == 1)
        let csv = try await HistoryExport.data(
            .daysCSV, from: store, dialect: .decimalComma, info: info, timeZone: moscow)
        #expect(String(decoding: csv, as: UTF8.self).components(separatedBy: "\r\n").count == 3)
    }
}

import BatteryCore
import BatterySource
import Foundation

/// `--record`: reads the battery every 5 s and keeps captures and a timeline in `folder`
/// (``CaptureRecorder``). Runs until interrupted or the timeline limit; each file is complete on
/// disk as soon as it is written, so Control-C loses nothing.
@MainActor
func record(into folder: String) async throws -> Never {
    // The battery first, so nothing is created where there is none.
    guard let provider = SystemBattery.makeProvider() else {
        fail("bpulse: battery information is not available on this platform.", code: 2)
    }
    var reading = provider.read()
    var readAt = Date()
    guard reading != nil else {
        fail("bpulse: no internal battery found.", code: 2)
    }

    let folderURL = URL(fileURLWithPath: NSString(string: folder).expandingTildeInPath)
    let timelineURL = folderURL.appendingPathComponent(CaptureRecorder.timelineFileName)
    if FileManager.default.fileExists(atPath: timelineURL.path) {
        fail("bpulse: \(folder) already holds a recording; choose a new folder.", code: 1)
    }
    let timeline: FileHandle
    do {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data((CaptureRecorder.timelineHeader + "\n").utf8).write(to: timelineURL)
        timeline = try FileHandle(forWritingTo: timelineURL)
        // The handle opens at offset 0: without this, the first row would overwrite the header.
        try timeline.seekToEnd()
    } catch {
        fail("bpulse: cannot write \(timelineURL.path): \(error.localizedDescription)", code: 1)
    }

    print("Recording to \(folderURL.path) every 5 s. Press Control-C to stop.")
    fflush(nil)
    var recorder = CaptureRecorder()
    while true {
        let step = recorder.record(reading, at: readAt)
        for capture in step.captures {
            let url = folderURL.appendingPathComponent(capture.fileName)
            do {
                try PropertyValue.xmlPropertyListData(capture.reading.redactedRawCapture).write(
                    to: url, options: .atomic)
            } catch {
                fail("bpulse: cannot write \(url.path): \(error.localizedDescription)", code: 1)
            }
        }
        do {
            // An unbuffered write: an interrupt never leaves half a row behind.
            try timeline.write(contentsOf: Data((step.timelineRow + "\n").utf8))
        } catch {
            fail("bpulse: cannot write \(timelineURL.path): \(error.localizedDescription)", code: 1)
        }
        if let summary = step.summary { print(summary) }
        for notice in step.notices { print(notice) }
        fflush(nil)
        if step.isFinished {
            print("Reached \(CaptureRecorder.defaultMaxTimelineRows) readings; stopped.")
            exit(0)
        }
        try await Task.sleep(for: CaptureRecorder.sampleInterval)
        reading = provider.read()
        readAt = Date()
    }
}

import Foundation
import Testing

/// The build-number clock (0.7.1's B-1): both workflows take `BUILD_NUMBER`, the app's and the
/// widget's `CFBundleVersion`, from `scripts/build-number.sh`, read once per job before the first
/// packaging step, so a release sits above every candidate built before it. WidgetKit caches a
/// widget's description by that number.
@Suite struct BuildNumberTests {
    private static let root = SourceScanner.sources.deletingLastPathComponent()
    private static let script = root.appendingPathComponent("scripts/build-number.sh")
    /// 2026-01-01T00:00:00Z, the clock's zero.
    private static let epoch = 1_767_225_600

    /// One step of a workflow: its job, and its lines without the comments.
    private struct Step {
        let job: String
        let code: [String]
        var text: String { code.joined(separator: "\n") }
        var name: String {
            code.first { $0.hasPrefix("- name: ") }.map { String($0.dropFirst("- name: ".count)) } ?? text
        }
    }

    private static func workflow(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(".github/workflows/\(name)"), encoding: .utf8)
    }

    /// The steps of every job, in order. A job starts at a two-space key under `jobs:`, a step at
    /// a dash six spaces in, as both workflows write them; a line further in belongs to its step.
    private static func steps(of workflow: String) -> [Step] {
        var steps: [Step] = []
        var job: String?
        var lines: [String] = []
        func close() {
            if let job, !lines.isEmpty { steps.append(Step(job: job, code: lines)) }
            lines = []
        }
        for line in workflow.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indent = line.prefix { $0 == " " }.count
            if indent < 6 {
                close()
                if indent == 0 {
                    job = nil
                } else if indent == 2 && trimmed.hasSuffix(":") {
                    job = String(trimmed.dropLast())
                }
            } else if indent == 6 && trimmed.hasPrefix("- ") {
                close()
                lines.append(trimmed)
            } else if !lines.isEmpty {
                lines.append(trimmed)
            }
        }
        close()
        return steps
    }

    @Test func noWorkflowUsesTheRunNumber() throws {
        for name in ["ci.yml", "release.yml"] {
            let text = try Self.workflow(name)
            #expect(!text.contains("run_number"), "\(name)")
            let code = text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            #expect(!code.contains { $0.contains("BUILD_NUMBER:") }, "\(name) sets BUILD_NUMBER in an env: block")
        }
    }

    /// Each workflow reads the clock in one step, into `$GITHUB_ENV`, before its first packaging
    /// step, and no packaging step sets a number of its own: so `ci.yml`'s profiling build carries
    /// the DMG's number, as its comment promises.
    @Test(arguments: [("ci.yml", 2), ("release.yml", 1)])
    func everyPackagingStepTakesTheClock(workflow name: String, packagingSteps: Int) throws {
        let steps = Self.steps(of: try Self.workflow(name))
        let readers = steps.indices.filter { steps[$0].text.contains("scripts/build-number.sh") }
        #expect(readers.count == 1, "\(name): \(readers.map { steps[$0].name })")
        let reader = try #require(readers.first)
        #expect(steps[reader].code.contains(#"echo "BUILD_NUMBER=$build_number" >> "$GITHUB_ENV""#), "\(name)")
        // Never skipped: build-app.sh would fall back to build 1, and release.yml doesn't read the
        // packaged number back.
        #expect(
            !steps[reader].code.contains { $0.hasPrefix("if:") || $0.hasPrefix("- if:") },
            "\(name): the reader runs on a condition")
        let packagers = steps.indices.filter { steps[$0].text.contains("scripts/build-app.sh") }
        #expect(packagers.count == packagingSteps, "\(name): \(packagers.map { steps[$0].name })")
        for packager in packagers {
            let step = steps[packager]
            #expect(step.job == steps[reader].job, "\(name): \(step.name)")
            #expect(packager > reader, "\(name): \(step.name) runs before the clock is read")
            #expect(!step.text.contains("BUILD_NUMBER="), "\(name): \(step.name) sets its own number")
        }
        // Only the reader writes the number, so no step in between replaces it.
        let writers = steps.filter { $0.text.contains("BUILD_NUMBER=") }
        #expect(writers.map(\.name) == [steps[reader].name], "\(name)")
    }

    /// The release reads the clock with the same lines as CI, which runs them on every push:
    /// release.yml runs only when a version is released.
    @Test func bothWorkflowsReadTheClockAlike() throws {
        func reader(_ name: String) throws -> [String] {
            let step = try #require(
                Self.steps(of: try Self.workflow(name)).first { $0.text.contains("scripts/build-number.sh") })
            return Array(step.code.drop { !$0.hasPrefix("run:") })
        }
        let ci = try reader("ci.yml")
        #expect(ci.count > 1)
        #expect(try reader("release.yml") == ci)
    }

    /// The script prints the whole seconds since 2026-01-01T00:00:00Z, now. The workflows run it
    /// by its path, so it stays executable.
    @Test func printsTheSecondsSince2026() throws {
        #expect(FileManager.default.isExecutableFile(atPath: Self.script.path))
        let zero = Date(timeIntervalSince1970: TimeInterval(Self.epoch))
        #expect(zero.formatted(.iso8601) == "2026-01-01T00:00:00Z")
        #expect(try String(contentsOf: Self.script, encoding: .utf8).contains("\nEPOCH=\(Self.epoch)\n"))

        let before = Int(Date().timeIntervalSince1970) - Self.epoch
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [Self.script.path]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let after = Int(Date().timeIntervalSince1970) - Self.epoch
        #expect(process.terminationStatus == 0)

        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasSuffix("\n"))
        let digits = text.dropLast()
        #expect(!digits.isEmpty && digits.allSatisfy { ("0"..."9").contains($0) }, "\(text)")
        let number = try #require(Int(digits))
        #expect((before...after).contains(number), "\(number) not in \(before)...\(after)")
        // Above 0.7.0's release, build 9 of release.yml, and every ci.yml run number so far; a
        // CFBundleVersion of one integer, within Int32.
        #expect(number > 26_000_000)
        #expect(number > 9)
        #expect(number < Int(Int32.max))
    }
}

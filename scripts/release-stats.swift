// Prints the download counts of BatteryPulse's published releases as a Markdown table, newest
// first, with a total row last:
//
//   swift scripts/release-stats.swift                         # one GitHub API request
//   swift scripts/release-stats.swift --repo <owner>/<name>   # another repository's releases
//   swift scripts/release-stats.swift --input releases.json   # a saved response; - reads stdin
//   swift scripts/release-stats.swift --self-test
//
// The columns are the ones ROADMAP's Releases table takes a week after each release: the DMG's
// downloads, its signature's (each in-app install fetches the signature, so it counts in-app
// updates) and, from 0.7 on, the anonymous version count's asset's. A release without one of these
// assets shows "—", never 0. Drafts and other assets are left out; a pre-release is marked, and the
// total counts it.
//
// The request is unauthenticated: it sends no token and reads none. GitHub allows 60 such requests
// an hour per address, and an address shared with other users can use them up, so a run makes one
// (one more per 100 releases past the first 100) and prints the requests left to stderr. When
// GitHub is limiting requests the script says until when and exits 2, without retrying. The
// authenticated route (5,000 requests an hour) saves the response first:
//
//   gh api 'repos/{owner}/{repo}/releases?per_page=100' > releases.json
//   swift scripts/release-stats.swift --input releases.json
//
// Exit status: 0 with the table, 1 on a usage, network, HTTP or decoding error, 2 while GitHub is
// limiting requests. It needs only Foundation, so it also runs on Linux.
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The anonymous version count's release asset, from v0.7.0 on (the 0.7 plan's W-13 freezes the
/// name). No earlier release has it, so its column reads "—" before then.
let countAsset = "BatteryPulse-count.txt"
let dmgAsset = "BatteryPulse.dmg"
let signatureAsset = "BatteryPulse.dmg.sig"
let defaultRepository = "NikitaUsov/BatteryPulse"
let missing = "—"

let usage = """
    usage: swift scripts/release-stats.swift [--repo <owner>/<name>]
           swift scripts/release-stats.swift --input <releases.json | ->
           swift scripts/release-stats.swift --self-test
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func note(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

/// The fields of one release in GitHub's "List releases" response that the table uses.
struct Release: Decodable {
    struct Asset: Decodable {
        let name: String
        let downloadCount: Int

        enum CodingKeys: String, CodingKey {
            case name
            case downloadCount = "download_count"
        }
    }

    let tagName: String
    /// Nil for a draft.
    let publishedAt: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case publishedAt = "published_at"
        case draft
        case prerelease
        case assets
    }

    /// The asset's download count, or nil when the release doesn't have it.
    func downloads(of asset: String) -> Int? { assets.first { $0.name == asset }?.downloadCount }
}

func decodeReleases(_ data: Data) throws -> [Release] { try JSONDecoder().decode([Release].self, from: data) }

func publishingDate(_ release: Release) -> Date? {
    guard let text = release.publishedAt else { return nil }
    return try? Date(text, strategy: .iso8601)
}

/// The Markdown table: the published releases newest first, then the total of each column ("—"
/// when no release has that asset). Numbers are right-aligned and every column is padded, so the
/// table also reads in a terminal.
func releaseTable(_ releases: [Release]) -> String {
    let published = releases.compactMap { release -> (release: Release, date: Date)? in
        guard !release.draft, let date = publishingDate(release) else { return nil }
        return (release, date)
    }
    // The sort is stable, so releases published in the same second keep GitHub's order.
    .sorted { $0.date > $1.date }
    let columns = [dmgAsset, signatureAsset, countAsset]
    func cell(_ count: Int?) -> String { count.map(String.init) ?? missing }

    var rows = [["Tag", "Published (UTC)", "DMG", "Signature", "Count"]]
    var totals: [Int?] = Array(repeating: nil, count: columns.count)
    for (release, date) in published {
        let tag = release.prerelease ? "\(release.tagName) (pre-release)" : release.tagName
        var row = [tag, date.formatted(.iso8601.year().month().day())]
        for (index, asset) in columns.enumerated() {
            let count = release.downloads(of: asset)
            if let count { totals[index] = (totals[index] ?? 0) + count }
            row.append(cell(count))
        }
        rows.append(row)
    }
    rows.append(["Total", ""] + totals.map(cell))

    let rightAligned = [false, false, true, true, true]
    var widths = rows[0].map { _ in 3 }
    for row in rows {
        for (column, text) in row.enumerated() { widths[column] = max(widths[column], text.count) }
    }
    func line(_ cells: [String]) -> String { "| " + cells.joined(separator: " | ") + " |" }
    func padded(_ row: [String]) -> [String] {
        row.enumerated().map { column, text in
            let padding = String(repeating: " ", count: widths[column] - text.count)
            return rightAligned[column] ? padding + text : text + padding
        }
    }
    let rule = widths.enumerated().map { column, width in
        rightAligned[column] ? String(repeating: "-", count: width - 1) + ":" : String(repeating: "-", count: width)
    }
    return ([line(padded(rows[0])), line(rule)] + rows.dropFirst().map { line(padded($0)) }).joined(separator: "\n")
}

/// The status and headers of one response; header names are matched without regard to case.
struct ResponseHead {
    let status: Int
    let headers: [String: String]

    init(status: Int, headers: [String: String]) {
        self.status = status
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }) { first, _ in first }
    }

    func header(_ name: String) -> String? { headers[name.lowercased()] }
}

/// What a response means for the run.
enum Outcome: Equatable {
    case success
    /// GitHub is limiting requests until then.
    case limited(until: Date)
    /// Any other HTTP status.
    case failed(status: Int)
}

/// GitHub's rate-limit rules: a 403 or 429 is a limit when `X-RateLimit-Remaining` is 0 (wait
/// for `X-RateLimit-Reset`, in seconds since 1970) or when it carries `Retry-After` (seconds, or
/// an HTTP date); with neither time given, wait at least a minute.
func outcome(of head: ResponseHead, now: Date) -> Outcome {
    if (200..<300).contains(head.status) { return .success }
    let remaining = head.header("X-RateLimit-Remaining")?.trimmingCharacters(in: .whitespaces)
    let retryAfter = head.header("Retry-After")?.trimmingCharacters(in: .whitespaces)
    guard [403, 429].contains(head.status), remaining == "0" || retryAfter != nil else {
        return .failed(status: head.status)
    }
    if let retryAfter {
        if let seconds = Int(retryAfter) { return .limited(until: now.addingTimeInterval(TimeInterval(seconds))) }
        if let date = httpDate(retryAfter) { return .limited(until: date) }
    }
    if let reset = head.header("X-RateLimit-Reset").flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }) {
        return .limited(until: Date(timeIntervalSince1970: TimeInterval(reset)))
    }
    return .limited(until: now.addingTimeInterval(60))
}

func exitStatus(of outcome: Outcome) -> Int32 {
    switch outcome {
    case .success: 0
    case .limited: 2
    case .failed: 1
    }
}

/// An HTTP date as `Retry-After` may carry it (RFC 9110's IMF-fixdate).
func httpDate(_ text: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    return formatter.date(from: text)
}

/// A time in the given (by default this Mac's) time zone, to the minute.
func localTime(_ date: Date, in timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
}

func limitMessage(until date: Date, in timeZone: TimeZone = .current) -> String {
    "GitHub is limiting requests until \(localTime(date, in: timeZone)); try again then, or pass a saved response "
        + "with --input"
}

/// The requests left this hour, as the response reports them; nil without the headers.
func quotaNote(_ head: ResponseHead, in timeZone: TimeZone = .current) -> String? {
    guard let remaining = head.header("X-RateLimit-Remaining"), let limit = head.header("X-RateLimit-Limit") else {
        return nil
    }
    var text = "GitHub API: \(remaining) of \(limit) requests left"
    if let reset = head.header("X-RateLimit-Reset").flatMap({ Int($0) }) {
        text += ", the count resets at \(localTime(Date(timeIntervalSince1970: TimeInterval(reset)), in: timeZone))"
    }
    return text
}

/// The `rel="next"` page of a `Link` header, which GitHub sends only when more releases follow.
func nextPage(_ link: String?) -> URL? {
    guard let link else { return nil }
    for part in link.split(separator: ",") {
        let fields = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.dropFirst().contains("rel=\"next\""), let target = fields.first, target.hasPrefix("<"),
            target.hasSuffix(">")
        else { continue }
        return URL(string: String(target.dropFirst().dropLast()))
    }
    return nil
}

/// Checks the rate-limit decision on canned statuses and headers, and the table on a canned
/// response; returns the failures.
func selfTest() -> [String] {
    var failures: [String] = []
    func check(_ condition: Bool, _ description: String) { if !condition { failures.append(description) } }
    let now = Date(timeIntervalSince1970: 1_792_800_000)
    let utc = TimeZone(identifier: "UTC") ?? .current

    let exhausted = outcome(
        of: ResponseHead(status: 403, headers: ["x-ratelimit-remaining": "0", "X-RateLimit-Reset": "1792803600"]),
        now: now)
    check(exhausted == .limited(until: Date(timeIntervalSince1970: 1_792_803_600)), "403, remaining 0: \(exhausted)")
    check(exitStatus(of: exhausted) == 2, "403, remaining 0: exit \(exitStatus(of: exhausted))")
    let expectedMessage =
        "GitHub is limiting requests until 2026-10-24 01:00; try again then, or pass a saved response with --input"
    check(limitMessage(until: Date(timeIntervalSince1970: 1_792_803_600), in: utc) == expectedMessage, "the message")

    let retry = outcome(of: ResponseHead(status: 429, headers: ["Retry-After": "120"]), now: now)
    check(retry == .limited(until: now.addingTimeInterval(120)), "429, Retry-After 120: \(retry)")
    check(exitStatus(of: retry) == 2, "429, Retry-After 120: exit \(exitStatus(of: retry))")
    let retryDate = outcome(
        of: ResponseHead(status: 403, headers: ["Retry-After": "Sat, 24 Oct 2026 00:30:00 GMT"]), now: now)
    check(
        retryDate == .limited(until: Date(timeIntervalSince1970: 1_792_801_800)), "403, Retry-After date: \(retryDate)")
    let noTime = outcome(of: ResponseHead(status: 429, headers: ["X-RateLimit-Remaining": "0"]), now: now)
    check(noTime == .limited(until: now.addingTimeInterval(60)), "429 without a time: \(noTime)")

    let forbidden = outcome(of: ResponseHead(status: 403, headers: ["X-RateLimit-Remaining": "41"]), now: now)
    check(forbidden == .failed(status: 403) && exitStatus(of: forbidden) == 1, "403 with requests left: \(forbidden)")
    let notFound = outcome(of: ResponseHead(status: 404, headers: [:]), now: now)
    check(notFound == .failed(status: 404) && exitStatus(of: notFound) == 1, "404: \(notFound)")
    let ok = outcome(of: ResponseHead(status: 200, headers: ["X-RateLimit-Remaining": "0"]), now: now)
    check(ok == .success && exitStatus(of: ok) == 0, "200: \(ok)")

    let quota = quotaNote(
        ResponseHead(
            status: 200,
            headers: ["X-RateLimit-Remaining": "59", "X-RateLimit-Limit": "60", "X-RateLimit-Reset": "1792803600"]),
        in: utc)
    check(quota == "GitHub API: 59 of 60 requests left, the count resets at 2026-10-24 01:00", "the quota note")
    let link =
        "<https://api.github.com/repositories/1/releases?per_page=100&page=2>; rel=\"next\", "
        + "<https://api.github.com/repositories/1/releases?per_page=100&page=3>; rel=\"last\""
    check(
        nextPage(link)?.absoluteString == "https://api.github.com/repositories/1/releases?per_page=100&page=2",
        "the next page")
    check(nextPage("<https://api.github.com/x?page=1>; rel=\"prev\"") == nil, "no next page")

    let response = """
        [{"tag_name": "v0.7.0", "published_at": "2026-12-01T10:00:00Z", "draft": false, "prerelease": false,
          "assets": [{"name": "BatteryPulse.dmg", "download_count": 12},
                     {"name": "BatteryPulse.dmg.sig", "download_count": 7},
                     {"name": "BatteryPulse-count.txt", "download_count": 1234}]},
         {"tag_name": "v0.7.1", "published_at": null, "draft": true, "prerelease": false,
          "assets": [{"name": "BatteryPulse.dmg", "download_count": 0}]},
         {"tag_name": "v0.3.0", "published_at": "2026-10-15T00:01:33Z", "draft": false, "prerelease": true,
          "assets": [{"name": "BatteryPulse.dmg", "download_count": 2},
                     {"name": "BatteryPulse-dSYMs.zip", "download_count": 9}]}]
        """
    let expectedTable = """
        | Tag                  | Published (UTC) | DMG | Signature | Count |
        | -------------------- | --------------- | --: | --------: | ----: |
        | v0.7.0               | 2026-12-01      |  12 |         7 |  1234 |
        | v0.3.0 (pre-release) | 2026-10-15      |   2 |         — |     — |
        | Total                |                 |  14 |         7 |  1234 |
        """
    do {
        let table = releaseTable(try decodeReleases(Data(response.utf8)))
        check(table == expectedTable, "the table:\n\(table)")
    } catch {
        failures.append("the canned response doesn't decode: \(error)")
    }
    return failures
}

enum Mode {
    case live(repository: String)
    case input(path: String)
    case selfTest
}

func parseArguments(_ arguments: [String]) -> Mode? {
    switch arguments.count {
    case 0: return .live(repository: defaultRepository)
    case 1 where arguments[0] == "--self-test": return .selfTest
    case 2 where arguments[0] == "--input": return .input(path: arguments[1])
    case 2 where arguments[0] == "--repo":
        let parts = arguments[1].split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        return .live(repository: arguments[1])
    default: return nil
    }
}

/// The response headers the run reads.
let headerNames = ["X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset", "Retry-After", "Link"]

func fetchReleases(of repository: String) async -> [Release] {
    guard var next = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=100") else {
        fail("'\(repository)' isn't a repository name")
    }
    // Nothing cached on disk, no cookies, and no credentials of any kind.
    let session = URLSession(configuration: .ephemeral)
    var releases: [Release] = []
    while true {
        var request = URLRequest(url: next)
        request.setValue("BatteryPulse-release-stats", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            fail("the request to \(next.absoluteString) failed: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else { fail("\(next.absoluteString) gave no HTTP response") }
        var headers: [String: String] = [:]
        for name in headerNames { headers[name] = http.value(forHTTPHeaderField: name) }
        let head = ResponseHead(status: http.statusCode, headers: headers)
        if let quota = quotaNote(head) { note(quota) }
        let result = outcome(of: head, now: Date())
        switch result {
        case .success:
            do {
                releases += try decodeReleases(data)
            } catch {
                fail("GitHub's response doesn't decode as a list of releases: \(error)")
            }
        case .limited(let until):
            note(limitMessage(until: until))
            exit(exitStatus(of: result))
        case .failed(let status):
            fail("GitHub answered \(next.absoluteString) with HTTP \(status)")
        }
        guard let page = nextPage(head.header("Link")) else { return releases }
        next = page
    }
}

guard let mode = parseArguments(Array(CommandLine.arguments.dropFirst())) else {
    note(usage)
    exit(1)
}
switch mode {
case .selfTest:
    let failures = selfTest()
    guard failures.isEmpty else { fail("the self-test failed:\n" + failures.joined(separator: "\n")) }
    print("The self-test passed.")
case .input(let path):
    let data: Data
    if path == "-" {
        data = FileHandle.standardInput.readDataToEndOfFile()
    } else {
        guard let contents = FileManager.default.contents(atPath: path) else { fail("can't read \(path)") }
        data = contents
    }
    do {
        print(releaseTable(try decodeReleases(data)))
    } catch {
        fail("\(path == "-" ? "stdin" : path) doesn't decode as a list of releases: \(error)")
    }
case .live(let repository):
    print(releaseTable(await fetchReleases(of: repository)))
}

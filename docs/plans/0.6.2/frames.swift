// Turns Session A's screen recordings into pictures a reviewer can look at (SESSION.md, step 6),
// and crops screenshots before they are published. The session script builds it once:
//
//   xcrun swiftc -O docs/plans/0.6.2/frames.swift -o ~/bp-062/A/bin/frames
//
//   frames dump <movie> <folder> [interval s, default 0.2] [width px, default 1280]
//       Writes frame-0000.png, frame-0001.png, … one per interval, scaled to the width;
//       sheet.png, every frame in order (rows of 10, left to right, top to bottom; at most 120,
//       evenly picked); and frames.tsv: index, time in s, mean luma (0-1), the share of dark
//       pixels (luma under 0.1, %) and the change from the first frame (%). It prints the frames
//       with the most dark pixels and the largest change, the ones to look at first.
//   frames crop <image> <x> <y> <width> <height> <output.png>
//       Pixels, from the top-left corner.
//
// AVFoundation, Core Graphics and Image I/O only; nothing leaves the Mac.
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct HelperError: Error, CustomStringConvertible {
    let description: String
}

/// One frame's numbers, from a small grey copy of it.
struct FrameStats {
    let luma: Double
    let darkShare: Double
    let grey: [UInt8]
}

/// Sizes, in an enum so they are plain constants in every language mode.
enum Layout {
    /// The width of the grey copy the numbers come from.
    static let statsWidth = 160
    static let sheetColumns = 10
    static let sheetCellWidth = 240
    /// The most frames on one contact sheet; longer clips are thinned evenly.
    static let sheetLimit = 120
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw HelperError(description: "can't create \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw HelperError(description: "can't write \(url.path)")
    }
}

func readImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw HelperError(description: "can't read \(url.path)") }
    return image
}

func stats(of image: CGImage) throws -> FrameStats {
    let height = max(1, Layout.statsWidth * image.height / max(1, image.width))
    guard
        let context = CGContext(
            data: nil, width: Layout.statsWidth, height: height, bitsPerComponent: 8, bytesPerRow: Layout.statsWidth,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { throw HelperError(description: "can't make a grey bitmap") }
    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: Layout.statsWidth, height: height))
    guard let data = context.data else { throw HelperError(description: "the grey bitmap has no pixels") }
    let count = Layout.statsWidth * height
    let grey = Array(UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: count), count: count))
    var sum = 0
    var dark = 0
    for value in grey {
        sum += Int(value)
        if value < 26 { dark += 1 }
    }
    return FrameStats(
        luma: Double(sum) / Double(count) / 255, darkShare: Double(dark) * 100 / Double(count), grey: grey)
}

/// The mean absolute difference between two grey copies, in percent of full scale.
func change(_ first: [UInt8], _ other: [UInt8]) -> Double {
    guard first.count == other.count, !first.isEmpty else { return 0 }
    var sum = 0
    for index in first.indices {
        sum += abs(Int(first[index]) - Int(other[index]))
    }
    return Double(sum) * 100 / Double(first.count) / 255
}

func contactSheet(_ frames: [CGImage]) throws -> CGImage? {
    guard let first = frames.first else { return nil }
    let step = max(1, (frames.count + Layout.sheetLimit - 1) / Layout.sheetLimit)
    let picked = stride(from: 0, to: frames.count, by: step).map { frames[$0] }
    let gap = 4
    let cellHeight = max(1, Layout.sheetCellWidth * first.height / max(1, first.width))
    let rows = (picked.count + Layout.sheetColumns - 1) / Layout.sheetColumns
    let width = Layout.sheetColumns * (Layout.sheetCellWidth + gap) + gap
    let height = rows * (cellHeight + gap) + gap
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw HelperError(description: "can't make the contact sheet") }
    // White gaps, so a black frame stands out from its neighbours.
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.interpolationQuality = .medium
    for (index, frame) in picked.enumerated() {
        let column = index % Layout.sheetColumns
        let row = index / Layout.sheetColumns
        // Core Graphics counts from the bottom; the sheet reads from the top.
        let x = gap + column * (Layout.sheetCellWidth + gap)
        let y = height - (row + 1) * (cellHeight + gap)
        context.draw(frame, in: CGRect(x: x, y: y, width: Layout.sheetCellWidth, height: cellHeight))
    }
    return context.makeImage()
}

func dump(movie: URL, folder: URL, interval: Double, width: Int) async throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let asset = AVURLAsset(url: movie)
    let duration = try await asset.load(.duration).seconds
    guard duration.isFinite, duration > 0 else { throw HelperError(description: "\(movie.path) has no duration") }
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        throw HelperError(description: "\(movie.path) has no video track")
    }
    let natural = try await track.load(.naturalSize)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    if natural.width > CGFloat(width) {
        generator.maximumSize = CGSize(width: CGFloat(width), height: natural.height * CGFloat(width) / natural.width)
    }

    var images: [CGImage] = []
    var lines = ["index\ttime_s\tluma\tdark_pct\tchange_pct"]
    var rows: [(index: Int, time: Double, stats: FrameStats, change: Double)] = []
    var firstGrey: [UInt8] = []
    var time = 0.0
    var index = 0
    sampling: while time < duration {
        let frame: (image: CGImage, actualTime: CMTime)
        do {
            frame = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
        } catch let error where index > 0 {
            // A clip's last moments may hold no frame to decode: keep the frames before them.
            FileHandle.standardError.write(
                Data("frames: stopped at \(String(format: "%.1f", time)) s: \(error)\n".utf8))
            break sampling
        }
        let (image, actual) = frame
        let name = String(format: "frame-%04ld.png", index)
        try writePNG(image, to: folder.appendingPathComponent(name))
        let frameStats = try stats(of: image)
        if index == 0 { firstGrey = frameStats.grey }
        let difference = change(firstGrey, frameStats.grey)
        rows.append((index, actual.seconds, frameStats, difference))
        lines.append(
            String(
                format: "%ld\t%.3f\t%.3f\t%.1f\t%.1f", index, actual.seconds, frameStats.luma, frameStats.darkShare,
                difference))
        images.append(image)
        index += 1
        time = Double(index) * interval
    }
    try (lines.joined(separator: "\n") + "\n").write(
        to: folder.appendingPathComponent("frames.tsv"), atomically: true, encoding: .utf8)
    if let sheet = try contactSheet(images) {
        try writePNG(sheet, to: folder.appendingPathComponent("sheet.png"))
    }

    print("\(rows.count) frames of \(String(format: "%.1f", duration)) s in \(folder.path)")
    print("sheet: \(folder.appendingPathComponent("sheet.png").path) (rows of \(Layout.sheetColumns), in order)")
    let darkest = rows.sorted { $0.stats.darkShare > $1.stats.darkShare }.prefix(5)
    print("most dark pixels: " + darkest.map { String(format: "frame-%04ld (%.1f %%)", $0.index, $0.stats.darkShare) }
        .joined(separator: ", "))
    let moved = rows.sorted { $0.change > $1.change }.prefix(5)
    print("largest change from the first frame: " + moved.map { String(format: "frame-%04ld (%.1f %%)", $0.index, $0.change) }
        .joined(separator: ", "))
}

func crop(image: URL, rect: CGRect, output: URL) throws {
    let source = try readImage(image)
    guard let cropped = source.cropping(to: rect) else {
        throw HelperError(description: "the rectangle is outside the \(source.width)×\(source.height) image")
    }
    try writePNG(cropped, to: output)
    print("\(output.path): \(cropped.width)×\(cropped.height)")
}

func run(_ arguments: [String]) async throws {
    let usage = HelperError(
        description: "usage: frames dump <movie> <folder> [interval s] [width px] | crop <image> <x> <y> <width> <height> <output.png>")
    guard arguments.count >= 2 else { throw usage }
    switch arguments[1] {
    case "dump":
        guard (4...6).contains(arguments.count) else { throw usage }
        let interval = arguments.count > 4 ? Double(arguments[4]) : 0.2
        let width = arguments.count > 5 ? Int(arguments[5]) : 1280
        guard let interval, interval > 0, let width, width > 0 else { throw usage }
        try await dump(
            movie: URL(fileURLWithPath: arguments[2]), folder: URL(fileURLWithPath: arguments[3]),
            interval: interval, width: width)
    case "crop":
        guard arguments.count == 8,
            let x = Int(arguments[3]), let y = Int(arguments[4]), let width = Int(arguments[5]),
            let height = Int(arguments[6]), width > 0, height > 0
        else { throw usage }
        try crop(
            image: URL(fileURLWithPath: arguments[2]), rect: CGRect(x: x, y: y, width: width, height: height),
            output: URL(fileURLWithPath: arguments[7]))
    default:
        throw usage
    }
}

do {
    try await run(CommandLine.arguments)
} catch {
    FileHandle.standardError.write(Data("frames: \(error)\n".utf8))
    exit(1)
}

// Turns the sessions' screen recordings into pictures and numbers a reviewer can check, and measures
// screenshots for the hands-free sessions' judgments (0.6.2's Session B, 0.7.0's Session R: every
// judgment pairs the session's reading of a picture with a pixel measurement). The session script
// builds it once:
//
//   xcrun swiftc -O docs/plans/0.7.0/frames.swift -o ~/bp-070/<R|C|H|D3>/bin/frames
//
//   frames dump <movie> <folder> [interval s, default 0.2] [width px, default 1280]
//               [--rect <x> <y> <width> <height> --screen <display width in points>]
//       Prints the movie's frame rate, then writes frame-0000.png, frame-0001.png, … one per
//       interval (zero tolerance, so 0.0167 dumps every frame of a 60 fps movie), scaled to the
//       width; sheet.png, the frames in order (rows of 10; at most 120, evenly picked); and
//       frames.tsv, every dumped frame: index, time in s, mean luma (0-1), the share of dark pixels
//       (luma under 0.1, %), the change from the first frame and from the previous one (%), and
//       with --rect the same luma and dark share inside the rectangle (display points, from the
//       top left; --screen scales them to the movie). It prints the frames with the most dark
//       pixels and the largest change, and with --rect writes the three darkest frames inside the
//       rectangle, cropped to it, as darkest-1.png … darkest-3.png.
//   frames fps <movie>
//   frames crop <image> <x> <y> <width> <height> <output.png>
//       Pixels, from the top-left corner (here and below).
//   frames stats <image> [<x> <y> <width> <height>]
//       luma, dark_pct and stddev (luma's standard deviation: near 0 for a blank or grey crop).
//   frames diff <image> <image> [<x> <y> <width> <height>]
//       mean_diff_pct, changed_pct (pixels with a channel more than 8 of 255 apart) and identical.
//   frames contrast <image> [<x> <y> <width> <height>]
//       An estimate of the text contrast inside the rectangle: the WCAG ratio between the 5th and
//       95th percentiles of the pixels' relative luminance (the contrast audit's fallback).
//   frames sheet <output.png> <image>...
//       A contact sheet of the images, in order (at most 120).
//   frames wallpaper bright|busy <output.png> <width> <height>
//       The generated wallpapers: an almost white gradient, and a high-contrast pattern of colour
//       bands and checks.
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

/// The rectangle in the image's pixels that a rectangle in display points covers.
func pixelRect(_ rect: CGRect, screenWidth: Double?, imageWidth: Int) -> CGRect {
    guard let screenWidth, screenWidth > 0 else { return rect }
    let scale = Double(imageWidth) / screenWidth
    return CGRect(
        x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale
    ).integral
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

/// The luma's standard deviation (0-1) of a grey copy.
func spread(_ grey: [UInt8]) -> Double {
    guard !grey.isEmpty else { return 0 }
    let mean = Double(grey.reduce(0) { $0 + Int($1) }) / Double(grey.count)
    let variance = grey.reduce(0.0) { $0 + (Double($1) - mean) * (Double($1) - mean) } / Double(grey.count)
    return variance.squareRoot() / 255
}

/// RGBA pixels of the image at its own size.
func rgba(_ image: CGImage) throws -> [UInt8] {
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { throw HelperError(description: "can't read the pixels") }
    return pixels
}

func cropped(_ image: CGImage, _ rect: CGRect?) throws -> CGImage {
    guard let rect else { return image }
    guard let part = image.cropping(to: rect) else {
        throw HelperError(description: "the rectangle is outside the \(image.width)×\(image.height) image")
    }
    return part
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

/// A rectangle in display points to measure inside, and the display's width in points.
struct Region {
    let rect: CGRect
    let screenWidth: Double?
}

func dump(movie: URL, folder: URL, interval: Double, width: Int, region: Region?) async throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let asset = AVURLAsset(url: movie)
    let duration = try await asset.load(.duration).seconds
    guard duration.isFinite, duration > 0 else { throw HelperError(description: "\(movie.path) has no duration") }
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        throw HelperError(description: "\(movie.path) has no video track")
    }
    let natural = try await track.load(.naturalSize)
    let rate = try await track.load(.nominalFrameRate)
    print(String(format: "frame rate: %.1f fps, %.0f×%.0f, %.2f s", rate, natural.width, natural.height, duration))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    if natural.width > CGFloat(width) {
        generator.maximumSize = CGSize(width: CGFloat(width), height: natural.height * CGFloat(width) / natural.width)
    }

    // Only the sheet's frames stay in memory (at most 120, evenly picked from the frames the clip
    // gives): a clip dumped frame by frame would otherwise hold hundreds of full frames.
    let expected = max(1, Int((duration / interval).rounded(.up)))
    let sheetStep = max(1, (expected + Layout.sheetLimit - 1) / Layout.sheetLimit)
    var sheetFrames: [CGImage] = []
    var lines = ["index\ttime_s\tluma\tdark_pct\tchange_pct\tstep_pct\trect_luma\trect_dark_pct"]
    var rows: [(index: Int, time: Double, stats: FrameStats, change: Double, inside: FrameStats?)] = []
    var firstGrey: [UInt8] = []
    var previousGrey: [UInt8] = []
    var time = 0.0
    var index = 0
    sampling: while time < duration {
        let frame: (image: CGImage, actualTime: CMTime)
        do {
            frame = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
        } catch let error where index > 0 {
            // A clip's last moments may hold no frame to decode: keep the frames before them.
            FileHandle.standardError.write(
                Data("frames: stopped at \(String(format: "%.3f", time)) s: \(error)\n".utf8))
            break sampling
        }
        let (image, actual) = frame
        let name = String(format: "frame-%04ld.png", index)
        try writePNG(image, to: folder.appendingPathComponent(name))
        let frameStats = try stats(of: image)
        if index == 0 { firstGrey = frameStats.grey }
        let difference = change(firstGrey, frameStats.grey)
        let step = index == 0 ? 0 : change(previousGrey, frameStats.grey)
        previousGrey = frameStats.grey
        var inside: FrameStats?
        if let region {
            // The rectangle in this frame's pixels: the movie's points scaled to the dumped width.
            let screenWidth = region.screenWidth ?? Double(natural.width)
            let box = pixelRect(region.rect, screenWidth: screenWidth, imageWidth: image.width)
            inside = try stats(of: try cropped(image, box))
        }
        rows.append((index, actual.seconds, frameStats, difference, inside))
        lines.append(
            String(
                format: "%ld\t%.3f\t%.3f\t%.1f\t%.1f\t%.1f\t%@\t%@", index, actual.seconds, frameStats.luma,
                frameStats.darkShare, difference, step,
                inside.map { String(format: "%.3f", $0.luma) } ?? "-",
                inside.map { String(format: "%.1f", $0.darkShare) } ?? "-"))
        if index % sheetStep == 0 { sheetFrames.append(image) }
        index += 1
        time = Double(index) * interval
    }
    try (lines.joined(separator: "\n") + "\n").write(
        to: folder.appendingPathComponent("frames.tsv"), atomically: true, encoding: .utf8)
    if let sheet = try contactSheet(sheetFrames) {
        try writePNG(sheet, to: folder.appendingPathComponent("sheet.png"))
    }

    print("\(rows.count) frames of \(String(format: "%.2f", duration)) s in \(folder.path)")
    print("sheet: \(folder.appendingPathComponent("sheet.png").path) (rows of \(Layout.sheetColumns), in order)")
    let darkest = rows.sorted { $0.stats.darkShare > $1.stats.darkShare }.prefix(5)
    print(
        "most dark pixels: "
            + darkest.map { String(format: "frame-%04ld (%.1f %%)", $0.index, $0.stats.darkShare) }
            .joined(separator: ", "))
    let moved = rows.sorted { $0.change > $1.change }.prefix(5)
    print(
        "largest change from the first frame: "
            + moved.map { String(format: "frame-%04ld (%.1f %%)", $0.index, $0.change) }
            .joined(separator: ", "))
    if let region {
        let screenWidth = region.screenWidth ?? Double(natural.width)
        let inside = rows.filter { $0.inside != nil }.sorted {
            ($0.inside?.darkShare ?? 0) > ($1.inside?.darkShare ?? 0)
        }
        for (rank, row) in inside.prefix(3).enumerated() {
            // Read back from its dump, the same pixels.
            let image = try readImage(folder.appendingPathComponent(String(format: "frame-%04ld.png", row.index)))
            let box = pixelRect(region.rect, screenWidth: screenWidth, imageWidth: image.width)
            try writePNG(try cropped(image, box), to: folder.appendingPathComponent("darkest-\(rank + 1).png"))
            print(
                String(
                    format: "darkest inside the rectangle %ld: frame-%04ld at %.3f s, luma %.3f, %.1f %% dark pixels",
                    rank + 1, row.index, row.time, row.inside?.luma ?? 0, row.inside?.darkShare ?? 0))
        }
    }
}

func crop(image: URL, rect: CGRect, output: URL) throws {
    let part = try cropped(try readImage(image), rect)
    try writePNG(part, to: output)
    print("\(output.path): \(part.width)×\(part.height)")
}

func measure(image: URL, rect: CGRect?) throws {
    let part = try cropped(try readImage(image), rect)
    let numbers = try stats(of: part)
    print(
        String(
            format: "luma=%.3f dark_pct=%.1f stddev=%.3f width=%ld height=%ld", numbers.luma, numbers.darkShare,
            spread(numbers.grey), part.width, part.height))
}

func compare(_ first: URL, _ second: URL, rect: CGRect?) throws {
    let one = try cropped(try readImage(first), rect)
    let other = try cropped(try readImage(second), rect)
    guard one.width == other.width, one.height == other.height else {
        print(
            "mean_diff_pct=- changed_pct=- identical=no (\(one.width)×\(one.height) against \(other.width)×\(other.height))"
        )
        return
    }
    let a = try rgba(one)
    let b = try rgba(other)
    var sum = 0
    var changed = 0
    var index = 0
    while index < a.count {
        var largest = 0
        for channel in 0..<3 {
            let difference = abs(Int(a[index + channel]) - Int(b[index + channel]))
            sum += difference
            largest = max(largest, difference)
        }
        if largest > 8 { changed += 1 }
        index += 4
    }
    let pixels = max(1, a.count / 4)
    print(
        String(
            format: "mean_diff_pct=%.3f changed_pct=%.3f identical=%@", Double(sum) * 100 / Double(pixels * 3) / 255,
            Double(changed) * 100 / Double(pixels), a == b ? "yes" : "no"))
}

/// WCAG's relative luminance of an sRGB pixel, 0-1.
func relativeLuminance(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> Double {
    func linear(_ value: UInt8) -> Double {
        let channel = Double(value) / 255
        return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
}

func contrast(image: URL, rect: CGRect?) throws {
    let part = try cropped(try readImage(image), rect)
    let pixels = try rgba(part)
    var values: [Double] = []
    values.reserveCapacity(pixels.count / 4)
    var index = 0
    while index + 2 < pixels.count {
        values.append(relativeLuminance(pixels[index], pixels[index + 1], pixels[index + 2]))
        index += 4
    }
    guard !values.isEmpty else { throw HelperError(description: "no pixels") }
    values.sort()
    let dark = values[values.count * 5 / 100]
    let light = values[min(values.count - 1, values.count * 95 / 100)]
    print(
        String(
            format: "contrast_ratio=%.2f dark_luminance=%.4f light_luminance=%.4f", (light + 0.05) / (dark + 0.05),
            dark, light))
}

func sheet(output: URL, images: [URL]) throws {
    guard let picture = try contactSheet(try images.map(readImage)) else { throw HelperError(description: "no images") }
    try writePNG(picture, to: output)
    print("\(output.path): \(images.count) images")
}

/// The generated wallpapers of Session B's screenshot set: bright, an almost white gradient; busy,
/// colour bands crossed by a black and white check, the hardest background for text contrast.
func wallpaper(kind: String, output: URL, width: Int, height: Int) throws {
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw HelperError(description: "can't make the wallpaper") }
    switch kind {
    case "bright":
        let rows = 64
        for row in 0..<rows {
            let shade = 0.93 + 0.07 * Double(row) / Double(rows - 1)
            context.setFillColor(CGColor(red: shade, green: shade, blue: min(1, shade + 0.02), alpha: 1))
            let top = height * row / rows
            context.fill(CGRect(x: 0, y: top, width: width, height: height * (row + 1) / rows - top))
        }
    case "busy":
        let colours: [(Double, Double, Double)] = [
            (0.9, 0.1, 0.1), (1, 0.8, 0), (0.1, 0.7, 0.2), (0, 0.4, 0.9), (0.6, 0.1, 0.8), (1, 1, 1), (0, 0, 0),
        ]
        let band = max(1, width / 28)
        for column in 0...(width / band) {
            let colour = colours[column % colours.count]
            context.setFillColor(CGColor(red: colour.0, green: colour.1, blue: colour.2, alpha: 1))
            context.fill(CGRect(x: column * band, y: 0, width: band, height: height))
        }
        let cell = max(1, height / 18)
        for row in 0...(height / cell) {
            for column in 0...(width / cell) where (row + column) % 2 == 0 && row % 3 == 0 {
                context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.85))
                context.fill(CGRect(x: column * cell, y: row * cell, width: cell, height: cell / 2))
                context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
                context.fill(CGRect(x: column * cell, y: row * cell + cell / 2, width: cell, height: cell / 2))
            }
        }
    default:
        throw HelperError(description: "a wallpaper is bright or busy")
    }
    guard let image = context.makeImage() else { throw HelperError(description: "can't make the wallpaper") }
    try writePNG(image, to: output)
    print("\(output.path): \(kind), \(width)×\(height)")
}

/// The optional pixel rectangle at the end of the arguments.
func trailingRect(_ arguments: [String], from index: Int) throws -> CGRect? {
    guard arguments.count > index else { return nil }
    let numbers = arguments[index...].compactMap(Int.init)
    guard arguments.count == index + 4, numbers.count == 4, numbers[2] > 0, numbers[3] > 0 else {
        throw HelperError(description: "a rectangle is <x> <y> <width> <height>, in pixels")
    }
    return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
}

func run(_ arguments: [String]) async throws {
    let usage = HelperError(
        description:
            "usage: frames dump <movie> <folder> [interval s] [width px] [--rect x y w h --screen W] | fps <movie> | crop <image> <x> <y> <width> <height> <output.png> | stats <image> [x y w h] | diff <image> <image> [x y w h] | contrast <image> [x y w h] | sheet <output.png> <image>... | wallpaper bright|busy <output.png> <width> <height>"
    )
    guard arguments.count >= 2 else { throw usage }
    switch arguments[1] {
    case "dump":
        var words = Array(arguments.dropFirst(2))
        var region: Region?
        if let at = words.firstIndex(of: "--rect") {
            guard at + 4 < words.count else { throw usage }
            let numbers = words[(at + 1)...(at + 4)].compactMap(Double.init)
            guard numbers.count == 4 else { throw usage }
            var screenWidth: Double?
            words.removeSubrange(at...(at + 4))
            if let screen = words.firstIndex(of: "--screen") {
                guard screen + 1 < words.count, let value = Double(words[screen + 1]) else { throw usage }
                screenWidth = value
                words.removeSubrange(screen...(screen + 1))
            }
            region = Region(
                rect: CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]),
                screenWidth: screenWidth)
        }
        guard (2...4).contains(words.count) else { throw usage }
        let interval = words.count > 2 ? Double(words[2]) : 0.2
        let width = words.count > 3 ? Int(words[3]) : 1280
        guard let interval, interval > 0, let width, width > 0 else { throw usage }
        try await dump(
            movie: URL(fileURLWithPath: words[0]), folder: URL(fileURLWithPath: words[1]), interval: interval,
            width: width, region: region)
    case "fps":
        guard arguments.count == 3 else { throw usage }
        let asset = AVURLAsset(url: URL(fileURLWithPath: arguments[2]))
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw HelperError(description: "\(arguments[2]) has no video track")
        }
        let rate = try await track.load(.nominalFrameRate)
        print(String(format: "fps=%.1f", rate))
    case "crop":
        guard arguments.count == 8,
            let x = Int(arguments[3]), let y = Int(arguments[4]), let width = Int(arguments[5]),
            let height = Int(arguments[6]), width > 0, height > 0
        else { throw usage }
        try crop(
            image: URL(fileURLWithPath: arguments[2]), rect: CGRect(x: x, y: y, width: width, height: height),
            output: URL(fileURLWithPath: arguments[7]))
    case "stats":
        guard arguments.count == 3 || arguments.count == 7 else { throw usage }
        try measure(image: URL(fileURLWithPath: arguments[2]), rect: try trailingRect(arguments, from: 3))
    case "diff":
        guard arguments.count == 4 || arguments.count == 8 else { throw usage }
        try compare(
            URL(fileURLWithPath: arguments[2]), URL(fileURLWithPath: arguments[3]),
            rect: try trailingRect(arguments, from: 4))
    case "contrast":
        guard arguments.count == 3 || arguments.count == 7 else { throw usage }
        try contrast(image: URL(fileURLWithPath: arguments[2]), rect: try trailingRect(arguments, from: 3))
    case "sheet":
        guard arguments.count >= 4 else { throw usage }
        try sheet(output: URL(fileURLWithPath: arguments[2]), images: arguments[3...].map { URL(fileURLWithPath: $0) })
    case "wallpaper":
        guard arguments.count == 6, let width = Int(arguments[4]), let height = Int(arguments[5]), width > 0, height > 0
        else { throw usage }
        try wallpaper(kind: arguments[2], output: URL(fileURLWithPath: arguments[3]), width: width, height: height)
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

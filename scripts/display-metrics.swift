// Prints each display's name, size, scale, menu bar height and notch, for
// scripts/menu-bar-shots.sh (macOS).
//
//   swift scripts/display-metrics.swift
//   swift scripts/display-metrics.swift --wallpapers <folder>
//       Also writes light.png and dark.png to <folder>: plain wallpapers that give a light and a
//       dark menu bar.
//
// Displays are labelled by name, not by number: NSScreen.screens and `screencapture -D` may
// number external displays differently.
import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// A 64 × 64 PNG filled with one sRGB colour.
@MainActor
func writePlainImage(red: UInt8, green: UInt8, blue: UInt8, to url: URL) {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 3,
            hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let pixels = bitmap.bitmapData
    else { fail("cannot create a bitmap for \(url.lastPathComponent)") }
    let stride = bitmap.bitsPerPixel / 8
    for row in 0..<bitmap.pixelsHigh {
        for column in 0..<bitmap.pixelsWide {
            let offset = row * bitmap.bytesPerRow + column * stride
            pixels[offset] = red
            pixels[offset + 1] = green
            pixels[offset + 2] = blue
        }
    }
    guard let png = (bitmap.retagging(with: .sRGB) ?? bitmap).representation(using: .png, properties: [:]) else {
        fail("cannot encode \(url.lastPathComponent)")
    }
    do {
        try png.write(to: url)
    } catch {
        fail("cannot write \(url.path): \(error.localizedDescription)")
    }
}

/// The folder after `--wallpapers`, or nil without options.
func parseWallpaperFolder(_ arguments: [String]) -> String? {
    switch arguments.count {
    case 0: return nil
    case 2 where arguments[0] == "--wallpapers": return arguments[1]
    default: fail("usage: swift scripts/display-metrics.swift [--wallpapers <folder>]")
    }
}

let wallpaperFolder = parseWallpaperFolder(Array(CommandLine.arguments.dropFirst()))

MainActor.assumeIsolated {
    _ = NSApplication.shared
    for screen in NSScreen.screens {
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        let notch = screen.auxiliaryTopLeftArea != nil ? "yes" : "no"
        print(
            "\(screen.localizedName): \(Int(screen.frame.width))x\(Int(screen.frame.height)) pt; "
                + "scale \(screen.backingScaleFactor); menu bar \(menuBar) pt; "
                + "top inset \(screen.safeAreaInsets.top) pt; notch \(notch)")
    }
    print("status bar thickness: \(NSStatusBar.system.thickness) pt")

    if let wallpaperFolder {
        let folder = URL(fileURLWithPath: wallpaperFolder, isDirectory: true)
        // #F5F5F7 and #1D1D1F.
        writePlainImage(red: 0xF5, green: 0xF5, blue: 0xF7, to: folder.appendingPathComponent("light.png"))
        writePlainImage(red: 0x1D, green: 0x1D, blue: 0x1F, to: folder.appendingPathComponent("dark.png"))
    }
}

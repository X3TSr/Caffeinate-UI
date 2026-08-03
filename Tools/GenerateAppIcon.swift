#!/usr/bin/env swift

// Draws the app icon with CoreGraphics so the repository does not have to carry
// binary assets and the build needs no image tooling.
//
//     swift Tools/GenerateAppIcon.swift build/AppIcon.iconset
//
// Then turn the iconset into an .icns with:
//
//     iconutil -c icns build/AppIcon.iconset

import AppKit
import Foundation

// Everything is drawn in a 1024x1024 space and scaled down per size.
let canvas: CGFloat = 1024

let backgroundTop = NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.32, alpha: 1)
let backgroundBottom = NSColor(calibratedRed: 0.94, green: 0.40, blue: 0.13, alpha: 1)
let cupColor = NSColor.white

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not allocate a \(pixels)px bitmap")
    }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let scale = CGFloat(pixels) / canvas
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    drawBackground()
    drawCup(showDetails: pixels >= 128)

    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// macOS style rounded square, inset from the edges like a system icon.
func drawBackground() {
    let inset: CGFloat = 84
    let rect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190)

    let gradient = NSGradient(starting: backgroundTop, ending: backgroundBottom)
    gradient?.draw(in: path, angle: -75)

    // Soft highlight across the top so the icon does not look flat.
    NSGraphicsContext.saveGraphicsState()
    path.setClip()
    let highlight = NSGradient(
        starting: NSColor(white: 1, alpha: 0.28),
        ending: NSColor(white: 1, alpha: 0)
    )
    highlight?.draw(
        in: NSRect(x: inset, y: canvas * 0.52, width: canvas - inset * 2, height: canvas * 0.4),
        angle: -90
    )
    NSGraphicsContext.restoreGraphicsState()
}

func drawCup(showDetails: Bool) {
    cupColor.setFill()
    cupColor.setStroke()

    // Handle first, so the cup body draws over its inner edge.
    let handle = NSBezierPath()
    handle.appendArc(
        withCenter: NSPoint(x: 690, y: 545),
        radius: 92,
        startAngle: -78,
        endAngle: 78
    )
    handle.lineWidth = 46
    handle.lineCapStyle = .round
    handle.stroke()

    // Tapered body with rounded bottom corners.
    let body = NSBezierPath()
    body.move(to: NSPoint(x: 336, y: 664))
    body.line(to: NSPoint(x: 672, y: 664))
    body.appendArc(from: NSPoint(x: 640, y: 372), to: NSPoint(x: 368, y: 372), radius: 74)
    body.appendArc(from: NSPoint(x: 368, y: 372), to: NSPoint(x: 336, y: 664), radius: 74)
    body.close()
    body.fill()

    // Saucer.
    let saucer = NSBezierPath(
        roundedRect: NSRect(x: 286, y: 288, width: 452, height: 50),
        xRadius: 25,
        yRadius: 25
    )
    saucer.fill()

    guard showDetails else { return }

    // Coffee line inside the cup.
    let crema = NSBezierPath(
        roundedRect: NSRect(x: 372, y: 600, width: 264, height: 26),
        xRadius: 13,
        yRadius: 13
    )
    backgroundBottom.withAlphaComponent(0.35).setFill()
    crema.fill()

    // Steam.
    cupColor.withAlphaComponent(0.92).setStroke()
    for offsetX in [-118, 0, 118] as [CGFloat] {
        let steam = NSBezierPath()
        let baseX = 504 + offsetX
        steam.move(to: NSPoint(x: baseX, y: 726))
        steam.curve(
            to: NSPoint(x: baseX, y: 812),
            controlPoint1: NSPoint(x: baseX + 44, y: 754),
            controlPoint2: NSPoint(x: baseX - 44, y: 784)
        )
        steam.curve(
            to: NSPoint(x: baseX, y: 890),
            controlPoint1: NSPoint(x: baseX + 40, y: 838),
            controlPoint2: NSPoint(x: baseX - 30, y: 862)
        )
        steam.lineWidth = 26
        steam.lineCapStyle = .round
        steam.stroke()
    }
}

// MARK: - Entry point

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(
        Data("usage: GenerateAppIcon.swift <output.iconset>\n".utf8)
    )
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1])
try? FileManager.default.removeItem(at: outputDirectory)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// (base point size, scale) pairs required by iconutil.
let variants: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

for (points, scale) in variants {
    let pixels = points * scale
    let rep = drawIcon(pixels: pixels)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode the \(pixels)px icon")
    }
    let suffix = scale == 1 ? "" : "@\(scale)x"
    let name = "icon_\(points)x\(points)\(suffix).png"
    try data.write(to: outputDirectory.appendingPathComponent(name))
}

print("Wrote \(variants.count) icon sizes to \(outputDirectory.path)")

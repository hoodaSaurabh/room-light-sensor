#!/usr/bin/env swift

import AppKit
import Foundation

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetURL = rootURL.appendingPathComponent(".build/generated-app-icon.iconset", isDirectory: true)
let outputURL = rootURL.appendingPathComponent("Resources/AppIcon.icns")

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let iconFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let icnsRepresentations: [(String, Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024)
]

func drawIcon(size: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "AppIcon", code: 1)
    }

    let canvas = CGFloat(size)
    rep.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    NSColor.clear.setFill()
    rect.fill()

    let inset = canvas * 0.045
    let bodyRect = rect.insetBy(dx: inset, dy: inset)
    let corner = canvas * 0.22
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: corner, yRadius: corner)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = canvas * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -canvas * 0.012)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.set()

    NSGradient(
        starting: NSColor(calibratedRed: 0.12, green: 0.61, blue: 0.78, alpha: 1),
        ending: NSColor(calibratedRed: 0.72, green: 0.92, blue: 0.90, alpha: 1)
    )?.draw(in: body, angle: 315)

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inner = bodyRect.insetBy(dx: canvas * 0.075, dy: canvas * 0.075)
    let glass = NSBezierPath(roundedRect: inner, xRadius: canvas * 0.16, yRadius: canvas * 0.16)
    NSColor.white.withAlphaComponent(0.18).setFill()
    glass.fill()

    let center = NSPoint(x: canvas * 0.52, y: canvas * 0.54)
    let rayInner = canvas * 0.18
    let rayOuter = canvas * 0.32
    NSColor.white.withAlphaComponent(0.72).setStroke()

    for index in 0..<12 {
        let angle = (CGFloat(index) / 12) * 2 * .pi
        let start = NSPoint(
            x: center.x + cos(angle) * rayInner,
            y: center.y + sin(angle) * rayInner
        )
        let end = NSPoint(
            x: center.x + cos(angle) * rayOuter,
            y: center.y + sin(angle) * rayOuter
        )
        let ray = NSBezierPath()
        ray.move(to: start)
        ray.line(to: end)
        ray.lineWidth = max(2, canvas * 0.026)
        ray.lineCapStyle = .round
        ray.stroke()
    }

    let sunRect = NSRect(
        x: center.x - canvas * 0.135,
        y: center.y - canvas * 0.135,
        width: canvas * 0.27,
        height: canvas * 0.27
    )
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(ovalIn: sunRect).fill()

    let meterRect = NSRect(
        x: canvas * 0.31,
        y: canvas * 0.22,
        width: canvas * 0.38,
        height: canvas * 0.085
    )
    let meter = NSBezierPath(roundedRect: meterRect, xRadius: canvas * 0.04, yRadius: canvas * 0.04)
    NSColor.white.withAlphaComponent(0.92).setFill()
    meter.fill()
    NSColor(calibratedRed: 0.07, green: 0.39, blue: 0.52, alpha: 0.38).setStroke()
    meter.lineWidth = max(1, canvas * 0.006)
    meter.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 2)
    }

    return data
}

for (fileName, size) in iconFiles {
    let data = try drawIcon(size: size)
    try data.write(to: iconsetURL.appendingPathComponent(fileName))
}

func appendBigEndianUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

func appendFourCharacterCode(_ value: String, to data: inout Data) {
    data.append(contentsOf: value.utf8)
}

var elements = Data()
for (type, size) in icnsRepresentations {
    let pngData = try drawIcon(size: size)
    appendFourCharacterCode(type, to: &elements)
    appendBigEndianUInt32(UInt32(pngData.count + 8), to: &elements)
    elements.append(pngData)
}

var icnsData = Data()
appendFourCharacterCode("icns", to: &icnsData)
appendBigEndianUInt32(UInt32(elements.count + 8), to: &icnsData)
icnsData.append(elements)
try icnsData.write(to: outputURL)

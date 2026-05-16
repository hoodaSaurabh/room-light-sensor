#!/usr/bin/env swift

import AppKit
import Foundation

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetURL = rootURL.appendingPathComponent(".build/generated-app-icon.iconset", isDirectory: true)
let assetCatalogURL = rootURL.appendingPathComponent(".build/generated-app-icon.xcassets", isDirectory: true)
let appIconSetURL = assetCatalogURL.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let outputURL = rootURL.appendingPathComponent("Resources/AppIcon.icns")

try? fileManager.removeItem(at: iconsetURL)
try? fileManager.removeItem(at: assetCatalogURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: appIconSetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

struct IconFile {
    let fileName: String
    let pixelSize: Int
    let pointDimension: Int
    let pointSize: String
    let scale: String
    let icnsType: String
}

let iconFiles: [IconFile] = [
    IconFile(fileName: "icon_16x16.png", pixelSize: 16, pointDimension: 16, pointSize: "16x16", scale: "1x", icnsType: "ic04"),
    IconFile(fileName: "icon_16x16@2x.png", pixelSize: 32, pointDimension: 16, pointSize: "16x16", scale: "2x", icnsType: "ic11"),
    IconFile(fileName: "icon_32x32.png", pixelSize: 32, pointDimension: 32, pointSize: "32x32", scale: "1x", icnsType: "ic05"),
    IconFile(fileName: "icon_32x32@2x.png", pixelSize: 64, pointDimension: 32, pointSize: "32x32", scale: "2x", icnsType: "ic12"),
    IconFile(fileName: "icon_128x128.png", pixelSize: 128, pointDimension: 128, pointSize: "128x128", scale: "1x", icnsType: "ic07"),
    IconFile(fileName: "icon_128x128@2x.png", pixelSize: 256, pointDimension: 128, pointSize: "128x128", scale: "2x", icnsType: "ic13"),
    IconFile(fileName: "icon_256x256.png", pixelSize: 256, pointDimension: 256, pointSize: "256x256", scale: "1x", icnsType: "ic08"),
    IconFile(fileName: "icon_256x256@2x.png", pixelSize: 512, pointDimension: 256, pointSize: "256x256", scale: "2x", icnsType: "ic14"),
    IconFile(fileName: "icon_512x512.png", pixelSize: 512, pointDimension: 512, pointSize: "512x512", scale: "1x", icnsType: "ic09"),
    IconFile(fileName: "icon_512x512@2x.png", pixelSize: 1024, pointDimension: 512, pointSize: "512x512", scale: "2x", icnsType: "ic10")
]

func drawIcon(pixelSize: Int, pointDimension: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
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

    let canvas = CGFloat(pixelSize)
    rep.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    NSColor.clear.setFill()
    rect.fill()

    let inset = canvas * 0.055
    let bodyRect = rect.insetBy(dx: inset, dy: inset)
    let corner = canvas * 0.20
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: corner, yRadius: corner)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = canvas * 0.018
    shadow.shadowOffset = NSSize(width: 0, height: -canvas * 0.006)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.10)
    shadow.set()

    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    body.fill()

    NSColor(calibratedWhite: 0.82, alpha: 1).setStroke()
    body.lineWidth = max(1, canvas * 0.006)
    body.stroke()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let center = NSPoint(x: canvas * 0.50, y: canvas * 0.50)
    let markColor = NSColor(calibratedWhite: 0.24, alpha: 1)
    markColor.setStroke()

    let rayInner = canvas * 0.275
    let rayOuter = canvas * 0.395
    for index in 0..<8 {
        let angle = (CGFloat(index) / 8) * 2 * .pi
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
        ray.lineWidth = max(2, canvas * 0.045)
        ray.lineCapStyle = .round
        ray.stroke()
    }

    let sunRect = NSRect(
        x: center.x - canvas * 0.145,
        y: center.y - canvas * 0.145,
        width: canvas * 0.29,
        height: canvas * 0.29
    )
    let sun = NSBezierPath(ovalIn: sunRect)
    sun.lineWidth = max(2, canvas * 0.055)
    sun.stroke()

    NSGraphicsContext.restoreGraphicsState()

    rep.size = NSSize(width: CGFloat(pointDimension), height: CGFloat(pointDimension))

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 2)
    }

    return data
}

for iconFile in iconFiles {
    let data = try drawIcon(pixelSize: iconFile.pixelSize, pointDimension: iconFile.pointDimension)
    try data.write(to: iconsetURL.appendingPathComponent(iconFile.fileName))
    try data.write(to: appIconSetURL.appendingPathComponent(iconFile.fileName))
}

struct AppIconContents: Encodable {
    struct Image: Encodable {
        let filename: String
        let idiom: String
        let scale: String
        let size: String
    }

    struct Info: Encodable {
        let author: String
        let version: Int
    }

    let images: [Image]
    let info: Info
}

let contents = AppIconContents(
    images: iconFiles.map {
        AppIconContents.Image(
            filename: $0.fileName,
            idiom: "mac",
            scale: $0.scale,
            size: $0.pointSize
        )
    },
    info: AppIconContents.Info(author: "xcode", version: 1)
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(contents).write(to: appIconSetURL.appendingPathComponent("Contents.json"))

try? fileManager.removeItem(at: outputURL)

func appendASCII(_ string: String, to data: inout Data) throws {
    guard let stringData = string.data(using: .ascii), stringData.count == 4 else {
        throw NSError(
            domain: "AppIcon",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "\(string) must be exactly four ASCII characters"]
        )
    }
    data.append(stringData)
}

func appendUInt32(_ value: Int, to data: inout Data) {
    var bigEndianValue = UInt32(value).bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

let iconChunks = try iconFiles.map { iconFile in
    (
        type: iconFile.icnsType,
        data: try Data(contentsOf: iconsetURL.appendingPathComponent(iconFile.fileName))
    )
}
let totalLength = 8 + iconChunks.reduce(0) { total, chunk in
    total + 8 + chunk.data.count
}

var icnsData = Data()
try appendASCII("icns", to: &icnsData)
appendUInt32(totalLength, to: &icnsData)

for chunk in iconChunks {
    try appendASCII(chunk.type, to: &icnsData)
    appendUInt32(8 + chunk.data.count, to: &icnsData)
    icnsData.append(chunk.data)
}

try icnsData.write(to: outputURL)

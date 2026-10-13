#!/usr/bin/env swift
// Draws the app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
// Follows the macOS icon grid: an 824 pt rounded square centred on a 1024 pt canvas.
import AppKit

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: size / 1024, y: size / 1024)

    let rgb = { (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) in CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a) }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    // Tile with drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0, 0, 0, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(rgb(24, 26, 32, 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Tile gradient and a soft top sheen.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [rgb(52, 56, 68, 1), rgb(18, 20, 25, 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    let sheen = CGGradient(colorsSpace: space, colors: [rgb(255, 255, 255, 0.10), rgb(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 600), options: [])
    ctx.restoreGState()

    // Hairline edge.
    ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 184, cornerHeight: 184, transform: nil))
    ctx.setStrokeColor(rgb(255, 255, 255, 0.08))
    ctx.setLineWidth(3)
    ctx.strokePath()

    let c = CGPoint(x: 512, y: 512)

    // Red glow behind the button.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let glow = CGGradient(colorsSpace: space, colors: [rgb(255, 69, 72, 0.35), rgb(255, 69, 72, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: c, startRadius: 150, endCenter: c, endRadius: 400, options: [])
    ctx.restoreGState()

    // Outer ring.
    ctx.addEllipse(in: CGRect(x: c.x - 250, y: c.y - 250, width: 500, height: 500))
    ctx.setStrokeColor(rgb(255, 92, 92, 0.45))
    ctx.setLineWidth(26)
    ctx.strokePath()

    // Record dot with gradient and highlight.
    let dot = CGRect(x: c.x - 180, y: c.y - 180, width: 360, height: 360)
    ctx.saveGState()
    ctx.addEllipse(in: dot)
    ctx.clip()
    let red = CGGradient(colorsSpace: space, colors: [rgb(255, 112, 108, 1), rgb(226, 44, 52, 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(red, start: CGPoint(x: c.x, y: dot.maxY), end: CGPoint(x: c.x, y: dot.minY), options: [])
    let hi = CGGradient(colorsSpace: space, colors: [rgb(255, 255, 255, 0.35), rgb(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
    let hc = CGPoint(x: c.x - 60, y: c.y + 90)
    ctx.drawRadialGradient(hi, startCenter: hc, startRadius: 0, endCenter: hc, endRadius: 200, options: [])
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let data = drawIcon(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try data.write(to: iconset.appendingPathComponent(name))
    }
}
let out = URL(fileURLWithPath: "Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run()
p.waitUntilExit()
guard p.terminationStatus == 0 else { fatalError("iconutil failed") }
try drawIcon(size: 1024).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "tmp/AppIcon-preview.png"))
print("Wrote \(out.path)")

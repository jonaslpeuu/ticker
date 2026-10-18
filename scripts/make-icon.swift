// Renders Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.20, green: 0.38, blue: 0.86, alpha: 1),
                        NSColor(red: 0.62, green: 0.32, blue: 0.82, alpha: 1),
                        NSColor(red: 0.98, green: 0.55, blue: 0.42, alpha: 1)])!
        .draw(in: shape, angle: -45)
    // Glass tile
    let tile = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.24)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: tile.height * 0.25, yRadius: tile.height * 0.25)
    NSColor.white.withAlphaComponent(0.28).setFill()
    tilePath.fill()
    NSColor.white.withAlphaComponent(0.7).setStroke()
    tilePath.lineWidth = max(1, s * 0.006)
    tilePath.stroke()
    let font = NSFont.systemFont(ofSize: tile.height * 0.62, weight: .semibold)
    let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: font.pointSize) } ?? font
    let text = NSAttributedString(string: "42", attributes: [.font: rounded, .foregroundColor: NSColor.white])
    let size = text.size()
    text.draw(at: NSPoint(x: tile.midX - size.width / 2, y: tile.midY - size.height / 2))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run()
p.waitUntilExit()
print("Wrote \(out.path)")

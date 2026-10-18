// Renders the DMG window background (Resources/dmg-background.tiff, 1x + 2x).
// Run: swift scripts/make-dmg-background.swift
//
// Deliberately minimal: plain white, a grey arrow between the icons, one small English hint line.
// Layout must match scripts/dmg-settings.py: background 660×400 pt, app icon centred at
// (180, 190), Applications at (480, 190), icon size 112.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let size = CGSize(width: 660, height: 400)
let appCenter = CGPoint(x: 180, y: 190), appsCenter = CGPoint(x: 480, y: 190)
let grey = NSColor(white: 0.0, alpha: 0.35)

func render(_ scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                               pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size // 2x image is marked as Retina
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
    // Flip to top-left origin so coordinates match Finder's icon positions.
    let flip = NSAffineTransform()
    flip.translateX(by: 0, yBy: size.height)
    flip.scaleX(by: 1, yBy: -1)
    flip.concat()

    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()

    // Arrow, vertically aligned with the icon centres.
    let y = appCenter.y
    let x0 = appCenter.x + 82, x1 = appsCenter.x - 82
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: x0, y: y))
    arrow.line(to: NSPoint(x: x1, y: y))
    arrow.move(to: NSPoint(x: x1 - 12, y: y - 12))
    arrow.line(to: NSPoint(x: x1, y: y))
    arrow.line(to: NSPoint(x: x1 - 12, y: y + 12))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    grey.setStroke()
    arrow.stroke()

    // One quiet hint line near the bottom.
    let font = NSFont.systemFont(ofSize: 12, weight: .regular)
    let hint = NSAttributedString(string: "Drag Ticker to Applications",
                                  attributes: [.font: font, .foregroundColor: NSColor(white: 0, alpha: 0.38)])
    let s = hint.size()
    // Text draws upside down in a manually flipped context, so flip it back locally.
    NSGraphicsContext.saveGraphicsState()
    let textFlip = NSAffineTransform()
    textFlip.translateX(by: 0, yBy: 330 + s.height)
    textFlip.scaleX(by: 1, yBy: -1)
    textFlip.concat()
    hint.draw(at: NSPoint(x: (size.width - s.width) / 2, y: 0))
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let tmp = FileManager.default.temporaryDirectory
let p1 = tmp.appendingPathComponent("dmg-bg.png"), p2 = tmp.appendingPathComponent("dmg-bg@2x.png")
try render(1).representation(using: .png, properties: [:])!.write(to: p1)
try render(2).representation(using: .png, properties: [:])!.write(to: p2)
let out = root.appendingPathComponent("Resources/dmg-background.tiff")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
p.arguments = ["-cathidpicheck", p1.path, p2.path, "-out", out.path]
try p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: root.appendingPathComponent("docs/images/dmg-background.png"))
print("Wrote \(out.path)")

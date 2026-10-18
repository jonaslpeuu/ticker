// Generates Ticker's app icons as Icon Composer documents (Resources/Icons/<id>.icon).
// The system renders them with real Liquid Glass (specular, translucency, dark/clear styles).
//   swift scripts/make-icons.swift && scripts/render-icon-previews.sh
// "tile" is the default app icon; the others can be picked in Settings → App-Icon.
import AppKit
import CoreText

let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Icons")
let C: CGFloat = 1024 // canvas

// MARK: SVG helpers

func svgPathData(_ path: CGPath) -> String {
    var d = ""
    path.applyWithBlock { el in
        let p = el.pointee.points
        func f(_ pt: CGPoint) -> String { String(format: "%.1f %.1f", pt.x, pt.y) }
        switch el.pointee.type {
        case .moveToPoint: d += "M\(f(p[0]))"
        case .addLineToPoint: d += "L\(f(p[0]))"
        case .addQuadCurveToPoint: d += "Q\(f(p[0])) \(f(p[1]))"
        case .addCurveToPoint: d += "C\(f(p[0])) \(f(p[1])) \(f(p[2]))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

/// Text as a path, centred at `center` (SVG coordinates, y down), cap height ≈ `height`.
func textPath(_ s: String, height: CGFloat, center: CGPoint, weight: NSFont.Weight = .bold) -> CGPath {
    let base = NSFont.systemFont(ofSize: 100, weight: weight)
    let font = (base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 100) } ?? base) as CTFont
    let size = 100 * height / CTFontGetCapHeight(font)
    let f = CTFontCreateCopyWithAttributes(font, size, nil, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(), &glyphs); CTRunGetPositions(run, CFRange(), &pos)
        for i in 0..<n {
            if let g = CTFontCreatePathForGlyph(f, glyphs[i], nil) {
                path.addPath(g, transform: CGAffineTransform(translationX: pos[i].x, y: pos[i].y))
            }
        }
    }
    let b = path.boundingBoxOfPath
    // flip y and centre
    var t = CGAffineTransform(translationX: center.x - b.midX, y: center.y + b.midY).scaledBy(x: 1, y: -1)
    return path.copy(using: &t)!
}

func roundRect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func svg(_ paths: [CGPath], fill: String = "#FFFFFF") -> String {
    let d = paths.map(svgPathData).joined()
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    <path d="\(d)" fill="\(fill)" fill-rule="nonzero"/>
    </svg>
    """
}

// MARK: .icon writer

struct Layer { var name: String; var svg: String; var glass = true; var opacity: Double = 1; var fill: String? = nil; var darkFill: String? = nil }
struct Group { var layers: [Layer]; var translucency = 0.4; var shadow = "neutral"; var specular = true }

func srgb(_ hex: String, _ a: Double = 1) -> String {
    let v = Int(hex.dropFirst(), radix: 16)!
    return String(format: "srgb:%.5f,%.5f,%.5f,%.5f", Double((v >> 16) & 255) / 255,
                  Double((v >> 8) & 255) / 255, Double(v & 255) / 255, a)
}

func writeIcon(_ name: String, fill: [String: Any], groups: [Group]) throws {
    let dir = out.appendingPathComponent("\(name).icon")
    let assets = dir.appendingPathComponent("Assets")
    try? FileManager.default.removeItem(at: dir)
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    var jsonGroups: [[String: Any]] = []
    for g in groups {
        var layers: [[String: Any]] = []
        for l in g.layers {
            try l.svg.write(to: assets.appendingPathComponent("\(l.name).svg"), atomically: true, encoding: .utf8)
            var j: [String: Any] = ["image-name": "\(l.name).svg", "name": l.name, "glass": l.glass]
            if l.opacity != 1 { j["opacity"] = l.opacity }
            if let f = l.fill, let d = l.darkFill {
                j["fill-specializations"] = [["value": ["solid": f]], ["appearance": "dark", "value": ["solid": d]]]
            } else if let f = l.fill { j["fill"] = ["solid": f] }
            layers.append(j)
        }
        jsonGroups.append([
            "layers": layers,
            "shadow": ["kind": g.shadow, "opacity": 0.5],
            "translucency": ["enabled": true, "value": g.translucency],
            "specular": g.specular,
        ])
    }
    let json: [String: Any] = [
        "fill": fill,
        "groups": jsonGroups,
        "supported-platforms": ["squares": ["macOS"]],
    ]
    let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: dir.appendingPathComponent("icon.json"))
}

let mid = CGPoint(x: C / 2, y: C / 2)

// 1 — Ticker tile: light background, frosted glass tile like the overlay, dark "42".
try writeIcon("tile", fill: ["linear-gradient": [srgb("#F4F6FB"), srgb("#D9DEEA")]], groups: [
    Group(layers: [
        Layer(name: "number", svg: svg([textPath("42", height: 250, center: mid)]), glass: false, fill: srgb("#1C1C22"), darkFill: srgb("#FFFFFF")),
    ], translucency: 0.0, specular: false),
    Group(layers: [
        Layer(name: "tile", svg: svg([roundRect(CGRect(x: 172, y: 302, width: 680, height: 420), 120)]), glass: true, opacity: 0.55),
    ], translucency: 0.6),
])

// 2 — Big glass "+1" on deep blue.
try writeIcon("plus-one", fill: ["linear-gradient": [srgb("#2F6BFF"), srgb("#0A1F7A")]], groups: [
    Group(layers: [
        Layer(name: "plusone", svg: svg([textPath("+1", height: 400, center: CGPoint(x: 500, y: 520))])),
    ], translucency: 0.35),
])

// 3 — Tally marks in glass on warm sunset.
var tally: [CGPath] = []
for i in 0..<4 {
    tally.append(roundRect(CGRect(x: 262 + CGFloat(i) * 140, y: 262, width: 76, height: 500), 38))
}
var strike = CGAffineTransform(translationX: 512, y: 512).rotated(by: -0.52).translatedBy(x: -330, y: -38)
let strikePath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 660, height: 76), cornerWidth: 38, cornerHeight: 38, transform: &strike)
try writeIcon("tally", fill: ["linear-gradient": [srgb("#FF9A3C"), srgb("#FF3B6B")]], groups: [
    Group(layers: [Layer(name: "bars", svg: svg(tally))], translucency: 0.3),
    Group(layers: [Layer(name: "strike", svg: svg([strikePath]))], translucency: 0.45),
])

// 4 — Rolling digits: three stacked glass pills like an odometer, on graphite.
try writeIcon("roller", fill: ["linear-gradient": [srgb("#3A3D4A"), srgb("#111216")]], groups: [
    // Groups are listed top-most first.
    Group(layers: [
        Layer(name: "digit", svg: svg([textPath("7", height: 190, center: mid)]), glass: false, fill: srgb("#1C1C22")),
    ], translucency: 0, specular: false),
    Group(layers: [
        Layer(name: "pill", svg: svg([roundRect(CGRect(x: 222, y: 372, width: 580, height: 280), 140)]), opacity: 0.9),
    ], translucency: 0.5),
    Group(layers: [
        Layer(name: "digit-prev", svg: svg([textPath("6", height: 120, center: CGPoint(x: 512, y: 250))]), glass: false, opacity: 0.35),
        Layer(name: "digit-next", svg: svg([textPath("8", height: 120, center: CGPoint(x: 512, y: 774))]), glass: false, opacity: 0.35),
    ], translucency: 0, specular: false),
])

print("Wrote icons to \(out.path)")

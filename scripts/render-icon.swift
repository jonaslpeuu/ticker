// Renders the system's icon for a bundle to a 1024 px PNG.
//   render-icon <bundle.app> <out.png> -AppleIconAppearanceTheme RegularLight|RegularDark
// Used by scripts/render-icon-previews.sh (compiled, so the argument domain applies).
import AppKit

let args = CommandLine.arguments
let image = NSWorkspace.shared.icon(forFile: args[1])
let px = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: px, height: px)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))

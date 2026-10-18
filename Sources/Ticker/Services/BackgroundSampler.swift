import AppKit
import ImageIO

/// Estimates whether the desktop behind a screen rectangle is dark, by sampling the wallpaper
/// image. Needs no Screen Recording permission. Falls back to the system appearance when the
/// wallpaper is not a readable image (e.g. dynamic/aerial wallpapers).
@MainActor
enum BackgroundSampler {
    private static var cache: [String: Bool] = [:]

    static func isDark(behind rect: NSRect, on screen: NSScreen) -> Bool {
        if DemoStage.isActive { return DemoStage.backdropIsDark }
        let key = "\(NSWorkspace.shared.desktopImageURL(for: screen)?.path ?? "-")|\(rect.integral)"
        if let cached = cache[key] { return cached }
        let result = sampleWallpaper(rect: rect, screen: screen).map { $0 < 0.55 } ?? systemIsDark
        cache[key] = result
        return result
    }

    static func invalidate() { cache.removeAll() }

    static var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Average relative luminance (0…1) of the wallpaper region under `rect`.
    private static func sampleWallpaper(rect: NSRect, screen: NSScreen) -> CGFloat? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 800,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        // Map screen rect -> image pixels, assuming "fill screen" scaling (the macOS default).
        let screenFrame = screen.frame
        let imgW = CGFloat(image.width), imgH = CGFloat(image.height)
        let scale = max(screenFrame.width / imgW, screenFrame.height / imgH)
        let offsetX = (imgW * scale - screenFrame.width) / 2
        let offsetY = (imgH * scale - screenFrame.height) / 2
        let localX = rect.minX - screenFrame.minX
        let localTop = screenFrame.maxY - rect.maxY // flip to top-left origin
        let crop = CGRect(x: (localX + offsetX) / scale, y: (localTop + offsetY) / scale,
                          width: rect.width / scale, height: rect.height / scale)
            .intersection(CGRect(x: 0, y: 0, width: imgW, height: imgH))
        guard !crop.isEmpty, let cropped = image.cropping(to: crop.integral) else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let r = CGFloat(pixel[0]) / 255, g = CGFloat(pixel[1]) / 255, b = CGFloat(pixel[2]) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

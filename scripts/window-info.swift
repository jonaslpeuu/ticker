// Helper for scripts/screenshots.sh.
//   swift window-info.swift screen      -> "<width> <height>" of the main screen (points)
//   swift window-info.swift ticker-top  -> "<x> <y> <w> <h>" of Ticker's highest on-screen window
//                                          below the overlay (top-left origin)
import AppKit

let mode = CommandLine.arguments.dropFirst().first ?? "screen"
let main = NSScreen.screens[0].frame

if mode == "screen" {
    print(Int(main.width), Int(main.height))
} else {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let ticker = list.filter {
        ($0[kCGWindowOwnerName as String] as? String) == "Ticker"
            && (($0[kCGWindowLayer as String] as? Int) ?? 0) < Int(CGWindowLevelForKey(.statusWindow))
    }
    // Highest layer first; the backdrop covers the whole screen, so skip it.
    let candidates = ticker
        .compactMap { info -> (Int, CGRect)? in
            guard let b = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let rect = CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!)
            guard rect.width < main.width else { return nil }
            return ((info[kCGWindowLayer as String] as? Int) ?? 0, rect)
        }
        .sorted { $0.0 > $1.0 }
    guard let r = candidates.first?.1 else { exit(1) }
    print(Int(r.minX), Int(r.minY), Int(r.width), Int(r.height))
}

// Prints the window ID of the first on-screen window whose title contains the argument.
// Used to screenshot exactly one window: screencapture -l "$(swift scripts/window-id.swift 'Ticker 1.0.0')"
// (Window titles are only visible with Screen Recording permission.)
import CoreGraphics
let needle = CommandLine.arguments.dropFirst().first ?? ""
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list where ((w[kCGWindowName as String] as? String) ?? "").contains(needle)
    && ((w[kCGWindowLayer as String] as? Int) ?? 1) == 0 {
    print(w[kCGWindowNumber as String] as! Int)
    break
}

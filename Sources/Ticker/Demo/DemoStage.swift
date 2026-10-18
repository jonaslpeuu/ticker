import AppKit
import SwiftUI

/// Screenshot / demo mode, used by `scripts/screenshots.sh` to produce the README images.
///
///     Ticker.app/Contents/MacOS/Ticker --demo <scene> [--backdrop dark|light] [-position center ...]
///
/// Scenes: `overlay` (only the glass counter), `settings` (settings window), `menu` (the menu bar
/// panel content). A full-screen sample backdrop is placed above normal windows (but below the
/// overlay and the menu bar), so the user's own wallpaper and windows never show up and nothing
/// on the system is changed. Preferences can be overridden for the run via the argument domain
/// (e.g. `-position center -counterValue 42`); they are read, not written.
@MainActor
enum DemoStage {
    static let scene: String? = value(after: "--demo")
    static var isActive: Bool { scene != nil }
    static var backdropIsDark: Bool { value(after: "--backdrop") != "light" }

    private static var windows: [NSWindow] = []

    static func start(model: AppModel) {
        guard let scene, let screen = NSScreen.screens.first else { return }
        showBackdrop(on: screen)

        switch scene {
        case "settings":
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = String(localized: "Ticker Settings")
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.toolbarStyle = .unifiedCompact
            window.level = .floating + 1
            window.center()
            window.orderFrontRegardless()
            windows.append(window)
        case "menu":
            let host = NSHostingView(rootView: MenuBarView(model: model))
            let size = host.fittingSize
            let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
            glass.cornerRadius = 18
            glass.contentView = host
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.level = .floating + 1
            panel.contentView = glass
            let visible = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - size.width - 120, y: visible.maxY - 6))
            panel.orderFrontRegardless()
            windows.append(panel)
        default:
            break
        }
        model.overlay.setPinned(scene == "overlay" || model.settings.visibility == .always)
    }

    private static func showBackdrop(on screen: NSScreen) {
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(rootView: DemoBackdrop(dark: backdropIsDark))
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        windows.append(window)
    }

    private static func value(after flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

/// A colourful, detailed sample wallpaper so the glass refraction and blur are visible.
private struct DemoBackdrop: View {
    let dark: Bool

    var body: some View {
        ZStack {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.62, 0.42], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: dark ? [
                .init(red: 0.05, green: 0.06, blue: 0.20), .init(red: 0.20, green: 0.10, blue: 0.45), .init(red: 0.95, green: 0.35, blue: 0.30),
                .init(red: 0.06, green: 0.25, blue: 0.55), .init(red: 0.45, green: 0.20, blue: 0.70), .init(red: 0.98, green: 0.60, blue: 0.25),
                .init(red: 0.02, green: 0.10, blue: 0.25), .init(red: 0.10, green: 0.45, blue: 0.65), .init(red: 0.35, green: 0.15, blue: 0.50),
            ] : [
                .init(red: 0.98, green: 0.90, blue: 0.80), .init(red: 0.85, green: 0.92, blue: 1.00), .init(red: 1.00, green: 0.80, blue: 0.85),
                .init(red: 0.80, green: 0.95, blue: 0.90), .init(red: 1.00, green: 0.97, blue: 0.92), .init(red: 0.90, green: 0.85, blue: 1.00),
                .init(red: 0.95, green: 0.88, blue: 0.75), .init(red: 0.75, green: 0.88, blue: 0.98), .init(red: 1.00, green: 0.90, blue: 0.80),
            ])

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    blob(dark ? .orange : .pink, size: h * 0.55).position(x: w * 0.86, y: h * 0.18)
                    blob(dark ? .cyan : .mint, size: h * 0.40).position(x: w * 0.74, y: h * 0.34)
                    blob(dark ? .purple : .yellow, size: h * 0.50).position(x: w * 0.50, y: h * 0.52)
                    blob(dark ? .pink : .teal, size: h * 0.35).position(x: w * 0.18, y: h * 0.22)
                    blob(dark ? .blue : .orange, size: h * 0.45).position(x: w * 0.25, y: h * 0.80)

                    // Sharp lines and type behind the glass make the refraction readable.
                    ForEach(0..<14) { i in
                        Capsule()
                            .fill(.white.opacity(dark ? 0.16 : 0.5))
                            .frame(width: w * 0.9, height: 3)
                            .rotationEffect(.degrees(-18))
                            .position(x: w * 0.5, y: h * (0.05 + Double(i) * 0.075))
                    }
                    Text(verbatim: "count anything.")
                        .font(.system(size: h * 0.16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(dark ? 0.22 : 0.55))
                        .position(x: w * 0.42, y: h * 0.62)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.95), color.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }
}

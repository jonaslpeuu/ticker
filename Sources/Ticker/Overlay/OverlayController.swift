import AppKit
import Observation
import SwiftUI

/// Owns the floating, click-through Liquid Glass panel that shows the counter.
@MainActor
@Observable
final class OverlayController {
    private(set) var isVisible = false
    /// Effective text color for the current position/background.
    private(set) var textIsWhite = true

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let counter: Counter
    @ObservationIgnored private var panel: NSPanel!
    @ObservationIgnored private var glass: NSGlassEffectView!
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    /// Shown persistently (not auto-hiding).
    @ObservationIgnored private var pinned = false

    /// Room around the glass so its edge highlights and shadow are not clipped.
    private let inset: CGFloat = 14

    init(settings: AppSettings, counter: Counter) {
        self.settings = settings
        self.counter = counter
        buildPanel()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                BackgroundSampler.invalidate()
                self?.layout()
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("AppleInterfaceThemeChangedNotification"),
                                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                BackgroundSampler.invalidate()
                self?.layout()
            }
        }
        pinned = settings.visibility == .always
        layout()
        if pinned { show() }
    }

    // MARK: Public API

    func settingsDidChange() {
        if settings.visibility == .always && !pinned {
            pinned = true
            show()
        }
        layout()
    }

    /// Called whenever the counter value changed.
    func valueDidChange() {
        switch settings.visibility {
        case .always, .manual:
            if pinned { show() }
        case .flash:
            flash()
        }
    }

    /// The "show" shortcut / menu toggle.
    func toggle() {
        if isVisible {
            pinned = false
            hide()
        } else if settings.visibility == .flash {
            flash()
        } else {
            pinned = true
            show()
        }
    }

    func setPinned(_ visible: Bool) {
        pinned = visible
        visible ? show() : hide()
    }

    /// Briefly shows the overlay where it is, e.g. while the user picks a position.
    func preview() {
        if !pinned { flash() } else { layout() }
    }

    // MARK: Showing / hiding

    private func flash() {
        show()
        hideTask?.cancel()
        let delay = settings.flashDuration
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, !self.pinned else { return }
            self.hide()
        }
    }

    private func show() {
        hideTask?.cancel()
        layout()
        guard !isVisible else { return }
        isVisible = true
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            panel.animator().alphaValue = 1
        }
    }

    private func hide() {
        hideTask?.cancel()
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isVisible else { return }
                self.panel.orderOut(nil)
            }
        })
    }

    // MARK: Layout

    private var targetScreen: NSScreen {
        switch settings.screen {
        case .primary:
            return NSScreen.screens.first ?? NSScreen.main!
        case .mouse:
            let mouse = NSEvent.mouseLocation
            return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        }
    }

    /// Glass size: a quarter of the screen height (× user scale), width from the aspect ratio.
    static func glassSize(for screen: NSScreen, settings: AppSettings) -> CGSize {
        let visible = screen.visibleFrame
        var height = (screen.frame.height / 4) * settings.sizeScale
        var width = height * settings.aspectRatio
        let maxW = visible.width - 2 * settings.screenMargin
        let maxH = visible.height - 2 * settings.screenMargin
        if width > maxW { width = maxW; height = width / settings.aspectRatio }
        if height > maxH { height = maxH; width = height * settings.aspectRatio }
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    private func layout() {
        let screen = targetScreen
        let visible = screen.visibleFrame
        let size = Self.glassSize(for: screen, settings: settings)
        let margin = settings.screenMargin
        let pos = settings.position

        let x: CGFloat = switch pos.column {
        case 0: visible.minX + margin
        case 1: visible.midX - size.width / 2
        default: visible.maxX - margin - size.width
        }
        let y: CGFloat = switch pos.row {
        case 0: visible.maxY - margin - size.height
        case 1: visible.midY - size.height / 2
        default: visible.minY + margin
        }
        let glassRect = NSRect(origin: CGPoint(x: x, y: y), size: size)
        panel.setFrame(glassRect.insetBy(dx: -inset, dy: -inset), display: true)

        glass.style = settings.glassStyle == .clear ? .clear : .regular
        glass.cornerRadius = min(size.height * 0.24, 56)

        let white: Bool = switch settings.textColor {
        case .white: true
        case .black: false
        case .auto: BackgroundSampler.isDark(behind: glassRect, on: screen)
        }
        textIsWhite = white
        // Match the glass material to the text so both read well together.
        panel.appearance = NSAppearance(named: white ? .darkAqua : .aqua)
    }

    private func buildPanel() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let container = NSView()
        container.wantsLayer = true

        let glass = NSGlassEffectView()
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView = NSHostingView(rootView: OverlayView(counter: counter, overlay: self))
        container.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            glass.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            glass.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            glass.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
        ])
        panel.contentView = container

        self.panel = panel
        self.glass = glass
    }
}

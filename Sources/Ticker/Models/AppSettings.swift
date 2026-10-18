import AppKit
import Observation

enum OverlayPosition: String, CaseIterable, Codable, Identifiable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: "Oben links"
        case .top: "Oben Mitte"
        case .topRight: "Oben rechts"
        case .left: "Links Mitte"
        case .center: "Mitte"
        case .right: "Rechts Mitte"
        case .bottomLeft: "Unten links"
        case .bottom: "Unten Mitte"
        case .bottomRight: "Unten rechts"
        }
    }

    /// 0 = left/top, 1 = middle, 2 = right/bottom.
    var column: Int { [0, 1, 2, 0, 1, 2, 0, 1, 2][Self.allCases.firstIndex(of: self)!] }
    var row: Int { Self.allCases.firstIndex(of: self)! / 3 }
}

enum TextColorMode: String, CaseIterable, Codable, Identifiable {
    case auto, white, black
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Automatisch"
        case .white: "Weiß"
        case .black: "Schwarz"
        }
    }
}

enum VisibilityMode: String, CaseIterable, Codable, Identifiable {
    case always, flash, manual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .always: "Immer sichtbar"
        case .flash: "Bei Änderung kurz einblenden"
        case .manual: "Nur per Tastenkürzel"
        }
    }
}

enum GlassStyle: String, CaseIterable, Codable, Identifiable {
    case regular, clear
    var id: String { rawValue }
    var title: String {
        switch self {
        case .regular: "Regular"
        case .clear: "Clear"
        }
    }
}

enum ScreenChoice: String, CaseIterable, Codable, Identifiable {
    case primary, mouse
    var id: String { rawValue }
    var title: String {
        switch self {
        case .primary: "Hauptbildschirm"
        case .mouse: "Bildschirm mit Mauszeiger"
        }
    }
}

/// All user preferences. Every property is persisted to `UserDefaults` on change and
/// `onChange` is called so the overlay / hotkeys can react.
@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var onHotkeysChange: (() -> Void)?

    // Counter
    var step: Int { didSet { store(step, "step") } }
    var startValue: Int { didSet { store(startValue, "startValue") } }
    var allowNegative: Bool { didSet { store(allowNegative, "allowNegative") } }
    var playSound: Bool { didSet { store(playSound, "playSound") } }
    var showCountInMenuBar: Bool { didSet { store(showCountInMenuBar, "showCountInMenuBar") } }

    // Overlay
    var position: OverlayPosition { didSet { store(position.rawValue, "position") } }
    var visibility: VisibilityMode { didSet { store(visibility.rawValue, "visibility") } }
    var flashDuration: Double { didSet { store(flashDuration, "flashDuration") } }
    var textColor: TextColorMode { didSet { store(textColor.rawValue, "textColor") } }
    var glassStyle: GlassStyle { didSet { store(glassStyle.rawValue, "glassStyle") } }
    var sizeScale: Double { didSet { store(sizeScale, "sizeScale") } }
    var aspectRatio: Double { didSet { store(aspectRatio, "aspectRatio") } }
    var screenMargin: Double { didSet { store(screenMargin, "screenMargin") } }
    var screen: ScreenChoice { didSet { store(screen.rawValue, "screen") } }

    // Shortcuts
    var hotkeys: [HotkeyAction: Hotkey] {
        didSet {
            if let data = try? JSONEncoder().encode(hotkeys) { defaults.set(data, forKey: "hotkeys") }
            onHotkeysChange?()
        }
    }

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "step": 1, "startValue": 0, "allowNegative": false, "playSound": false,
            "showCountInMenuBar": true,
            "position": OverlayPosition.topRight.rawValue,
            "visibility": VisibilityMode.flash.rawValue,
            "flashDuration": 2.5,
            "textColor": TextColorMode.auto.rawValue,
            "glassStyle": GlassStyle.regular.rawValue,
            "sizeScale": 1.0, "aspectRatio": 1.6, "screenMargin": 16.0,
            "screen": ScreenChoice.primary.rawValue,
        ])
        step = d.integer(forKey: "step")
        startValue = d.integer(forKey: "startValue")
        allowNegative = d.bool(forKey: "allowNegative")
        playSound = d.bool(forKey: "playSound")
        showCountInMenuBar = d.bool(forKey: "showCountInMenuBar")
        position = OverlayPosition(rawValue: d.string(forKey: "position") ?? "") ?? .topRight
        visibility = VisibilityMode(rawValue: d.string(forKey: "visibility") ?? "") ?? .flash
        flashDuration = d.double(forKey: "flashDuration")
        textColor = TextColorMode(rawValue: d.string(forKey: "textColor") ?? "") ?? .auto
        glassStyle = GlassStyle(rawValue: d.string(forKey: "glassStyle") ?? "") ?? .regular
        sizeScale = d.double(forKey: "sizeScale")
        aspectRatio = d.double(forKey: "aspectRatio")
        screenMargin = d.double(forKey: "screenMargin")
        screen = ScreenChoice(rawValue: d.string(forKey: "screen") ?? "") ?? .primary
        if DemoStage.isActive {
            hotkeys = Hotkey.defaults // screenshots always show the documented defaults
        } else if let data = d.data(forKey: "hotkeys"),
           let decoded = try? JSONDecoder().decode([HotkeyAction: Hotkey].self, from: data) {
            hotkeys = decoded
        } else {
            hotkeys = Hotkey.defaults
        }
    }

    func resetToDefaults() {
        let keys = ["step", "startValue", "allowNegative", "playSound", "showCountInMenuBar", "position",
                    "visibility", "flashDuration", "textColor", "glassStyle", "sizeScale",
                    "aspectRatio", "screenMargin", "screen"]
        keys.forEach { defaults.removeObject(forKey: $0) }
        let fresh = AppSettings()
        step = fresh.step; startValue = fresh.startValue; allowNegative = fresh.allowNegative
        playSound = fresh.playSound; showCountInMenuBar = fresh.showCountInMenuBar
        position = fresh.position; visibility = fresh.visibility; flashDuration = fresh.flashDuration
        textColor = fresh.textColor; glassStyle = fresh.glassStyle; sizeScale = fresh.sizeScale
        aspectRatio = fresh.aspectRatio; screenMargin = fresh.screenMargin; screen = fresh.screen
        hotkeys = Hotkey.defaults
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }
}

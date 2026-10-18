import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Actions that can be bound to a global keyboard shortcut.
enum HotkeyAction: String, CaseIterable, Codable, Identifiable {
    case increment, decrement, show, reset

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .increment: "Count up"
        case .decrement: "Count down"
        case .show: "Show / hide count"
        case .reset: "Reset"
        }
    }

    var symbol: String {
        switch self {
        case .increment: "plus.circle"
        case .decrement: "minus.circle"
        case .show: "eye"
        case .reset: "arrow.counterclockwise.circle"
        }
    }
}

/// A global shortcut. Either a key with modifiers (`keyCode != nil`, registered via Carbon,
/// needs no permissions) or a pure modifier combination like ⌃⇧ (`keyCode == nil`, fires when
/// the modifiers are released without another key in between, needs Accessibility access).
struct Hotkey: Codable, Equatable, Hashable {
    var keyCode: UInt16?
    var keyLabel: String?
    var modifierRaw: UInt

    static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    init(keyCode: UInt16?, keyLabel: String?, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.keyLabel = keyLabel
        self.modifierRaw = modifiers.intersection(Self.relevantModifiers).rawValue
    }

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierRaw) }
    var isModifierOnly: Bool { keyCode == nil }

    var displayString: String {
        Self.symbols(for: modifiers) + (keyLabel ?? "")
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    static func symbols(for flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    /// Human readable label for a key code, falling back to the typed character.
    static func label(for event: NSEvent) -> String {
        if let special = specialKeyLabels[event.keyCode] { return special }
        let chars = event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers ?? "?"
        return chars.uppercased()
    }

    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        specialKeyLabels[keyCode]?.hasPrefix("F") == true
    }

    static let specialKeyLabels: [UInt16: String] = [
        UInt16(kVK_Space): "Space", UInt16(kVK_Tab): "⇥", UInt16(kVK_Return): "↩",
        UInt16(kVK_Delete): "⌫", UInt16(kVK_ForwardDelete): "⌦", UInt16(kVK_Escape): "⎋",
        UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
        UInt16(kVK_DownArrow): "↓", UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_Home): "↖", UInt16(kVK_End): "↘",
        UInt16(kVK_PageUp): "⇞", UInt16(kVK_PageDown): "⇟",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
        UInt16(kVK_F13): "F13", UInt16(kVK_F14): "F14", UInt16(kVK_F15): "F15", UInt16(kVK_F16): "F16",
        UInt16(kVK_F17): "F17", UInt16(kVK_F18): "F18", UInt16(kVK_F19): "F19", UInt16(kVK_F20): "F20",
    ]

    static let defaults: [HotkeyAction: Hotkey] = [
        .increment: Hotkey(keyCode: nil, keyLabel: nil, modifiers: [.control, .shift]),
        .decrement: Hotkey(keyCode: UInt16(kVK_Delete), keyLabel: "⌫", modifiers: [.control, .shift]),
        .show: Hotkey(keyCode: UInt16(kVK_Space), keyLabel: "Space", modifiers: [.control, .shift]),
    ]
}

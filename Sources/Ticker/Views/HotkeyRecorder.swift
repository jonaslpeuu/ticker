import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a shortcut. Supports key combos (⌃⇧⌫) and modifier-only combos (⌃⇧):
/// for the latter press the modifiers together and release them.
struct HotkeyRecorder: View {
    @Binding var hotkey: Hotkey?

    @State private var isRecording = false
    @State private var liveModifiers: NSEvent.ModifierFlags = []
    @State private var hint: String?
    @State private var monitor = MonitorBox()

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .monospaced(hotkey != nil && !isRecording)
                    .foregroundStyle(isRecording ? Color.accentColor : (hotkey == nil ? .secondary : .primary))
                    .frame(minWidth: 130)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.glass)
            .help(isRecording ? "Esc zum Abbrechen" : "Klicken und neues Tastenkürzel drücken")

            if hotkey != nil && !isRecording {
                Button {
                    hotkey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Tastenkürzel entfernen")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize()
                    .offset(y: 18)
            }
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if isRecording {
            return liveModifiers.isEmpty ? "Tasten drücken…" : Hotkey.symbols(for: liveModifiers) + "…"
        }
        return hotkey?.displayString ?? "Kein Kürzel"
    }

    private func toggleRecording() {
        isRecording ? stop() : start()
    }

    private func start() {
        hint = nil
        liveModifiers = []
        isRecording = true
        HotkeyManager.shared.pause()
        var peak: NSEvent.ModifierFlags = []
        monitor.token = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            MainActor.assumeIsolated {
                let flags = event.modifierFlags.intersection(Hotkey.relevantModifiers)
                if event.type == .flagsChanged {
                    if flags.isEmpty {
                        if peak.count >= 2 {
                            commit(Hotkey(keyCode: nil, keyLabel: nil, modifiers: peak))
                        } else if !peak.isEmpty {
                            hint = "Nur-Modifier-Kürzel brauchen mindestens 2 Tasten"
                        }
                        peak = []
                    } else {
                        peak.formUnion(flags)
                    }
                    liveModifiers = flags
                    return
                }
                // keyDown
                if event.keyCode == UInt16(kVK_Escape) && flags.isEmpty {
                    stop()
                    return
                }
                if flags.isEmpty && !Hotkey.isFunctionKey(event.keyCode) {
                    hint = "Bitte mit ⌃, ⌥, ⇧ oder ⌘ kombinieren"
                    return
                }
                commit(Hotkey(keyCode: event.keyCode, keyLabel: Hotkey.label(for: event), modifiers: flags))
            }
            return nil
        }
    }

    private func commit(_ newValue: Hotkey) {
        hint = nil
        hotkey = newValue
        stop()
    }

    private func stop() {
        guard isRecording else { return }
        isRecording = false
        liveModifiers = []
        if let token = monitor.token { NSEvent.removeMonitor(token) }
        monitor.token = nil
        HotkeyManager.shared.resume()
    }
}

/// Reference box so the event monitor token survives view updates.
private final class MonitorBox {
    var token: Any?
}

private extension NSEvent.ModifierFlags {
    var count: Int {
        [NSEvent.ModifierFlags.control, .option, .shift, .command].filter { contains($0) }.count
    }
}

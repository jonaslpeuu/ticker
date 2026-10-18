import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"
    let model: AppModel

    var body: some View {
        TabView {
            Tab("Fenster", systemImage: "macwindow") { WindowSettings(model: model) }
            Tab("Tastenkürzel", systemImage: "keyboard") { ShortcutSettings(model: model) }
            Tab("Zähler", systemImage: "number") { CounterSettings(model: model) }
        }
        .frame(width: 540, height: 580)
    }
}

// MARK: - Fenster

private struct WindowSettings: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Position") {
                PositionPicker(selection: $settings.position) { model.overlay?.preview() }
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                Picker("Ausgewählt", selection: $settings.position) {
                    ForEach(OverlayPosition.allCases) { Text($0.title).tag($0) }
                }
                Picker("Bildschirm", selection: $settings.screen) {
                    ForEach(ScreenChoice.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Darstellung") {
                Picker("Textfarbe", selection: $settings.textColor) {
                    ForEach(TextColorMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Glas", selection: $settings.glassStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Größe") {
                    HStack {
                        Slider(value: $settings.sizeScale, in: 0.4...1.6, step: 0.05) { editing in
                            if !editing { model.overlay?.preview() }
                        }
                        Text(sizeDescription).monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                    }
                }
                LabeledContent("Seitenverhältnis") {
                    HStack {
                        Slider(value: $settings.aspectRatio, in: 1.0...3.0, step: 0.1) { editing in
                            if !editing { model.overlay?.preview() }
                        }
                        Text(String(format: "%.1f : 1", settings.aspectRatio)).monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                    }
                }
                LabeledContent("Randabstand") {
                    HStack {
                        Slider(value: $settings.screenMargin, in: 0...80, step: 2)
                        Text("\(Int(settings.screenMargin)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                    }
                }
            }

            Section("Sichtbarkeit") {
                Picker("Anzeigen", selection: $settings.visibility) {
                    ForEach(VisibilityMode.allCases) { Text($0.title).tag($0) }
                }
                if settings.visibility == .flash {
                    LabeledContent("Einblenddauer") {
                        HStack {
                            Slider(value: $settings.flashDuration, in: 0.5...10, step: 0.5)
                            Text(String(format: "%.1f s", settings.flashDuration)).monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                        }
                    }
                }
                Button("Vorschau zeigen") { model.overlay?.preview() }
            }
        }
        .formStyle(.grouped)
    }

    private var sizeDescription: String {
        settings.sizeScale == 1 ? "¼ Höhe" : String(format: "%.0f %%", model.settings.sizeScale * 100)
    }

    private var settings: AppSettings { model.settings }
}

// MARK: - Tastenkürzel

private struct ShortcutSettings: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { action in
                    LabeledContent {
                        HotkeyRecorder(hotkey: binding(for: action))
                    } label: {
                        Label(action.title, systemImage: action.symbol)
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("Globale Tastenkürzel")
            } footer: {
                Text("Klicke auf ein Kürzel und drücke die neue Kombination. Für reine Modifier-Kürzel (z. B. ⌃⇧) die Tasten gemeinsam drücken und loslassen – sie lösen beim Loslassen aus, wenn keine andere Taste dazwischen gedrückt wurde. Esc bricht ab.")
                    .foregroundStyle(.secondary)
            }

            Section("Berechtigung") {
                if model.hotkeys.isAccessibilityTrusted {
                    Label("Bedienungshilfen-Zugriff erteilt", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Label {
                        Text(model.hotkeys.needsAccessibility
                             ? "Für Modifier-Kürzel wie ⌃⇧ braucht Ticker Zugriff auf „Bedienungshilfen“."
                             : "Nur nötig für reine Modifier-Kürzel wie ⌃⇧.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    HStack {
                        Button("Zugriff anfragen") { model.hotkeys.requestAccessibility() }
                        Button("Systemeinstellungen öffnen") { model.hotkeys.openAccessibilitySettings() }
                    }
                    .buttonStyle(.glass)
                }
            }

            Section {
                Button("Standard-Kürzel wiederherstellen") { model.settings.hotkeys = Hotkey.defaults }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for action: HotkeyAction) -> Binding<Hotkey?> {
        Binding(
            get: { model.settings.hotkeys[action] },
            set: { model.settings.hotkeys[action] = $0 }
        )
    }
}

// MARK: - Zähler

private struct CounterSettings: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Zähler") {
                LabeledContent("Aktueller Stand") {
                    TextField("", value: Binding(get: { model.counter.value }, set: { model.set($0) }), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                Stepper("Schrittweite: \(settings.step)", value: $settings.step, in: 1...1000)
                LabeledContent("Startwert (Zurücksetzen)") {
                    TextField("", value: $settings.startValue, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                Toggle("Negative Werte erlauben", isOn: $settings.allowNegative)
                Toggle("Klick-Ton beim Zählen", isOn: $settings.playSound)
            }

            Section("App") {
                Toggle("Zahl in der Menüleiste anzeigen", isOn: $settings.showCountInMenuBar)
                Toggle("Bei Anmeldung starten", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.launchAtLogin = $0 }
                ))
            }

            Section {
                Button("Alle Einstellungen zurücksetzen", role: .destructive) { model.settings.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
    }
}

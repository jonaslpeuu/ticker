import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"
    let model: AppModel

    var body: some View {
        TabView {
            Tab("Fenster", systemImage: "macwindow") { WindowSettings(model: model) }
            Tab("Tastenkürzel", systemImage: "keyboard") { ShortcutSettings(model: model) }
            Tab("Zähler", systemImage: "number") { CounterSettings(model: model) }
            Tab("App-Icon", systemImage: "app.badge") { AppIconSettings(model: model) }
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

// MARK: - App-Icon

private struct AppIconSettings: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 16)]

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(AppIconChoice.allCases) { choice in
                        IconTile(choice: choice,
                                 isSelected: model.settings.appIcon == choice,
                                 dark: AppIconManager.systemIconsAreDark) {
                            withAnimation(.spring(duration: 0.3, bounce: 0.3)) { model.settings.appIcon = choice }
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("App-Icon")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let error = model.appIconError {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Text("„Kachel“ rendert macOS live in Liquid Glass, passend zu jedem Icon-Stil. Die anderen Icons werden als Bild passend zu deinem aktuellen Hell/Dunkel-Stil gesetzt. Finder und Programme-Ordner zeigen die Änderung nach wenigen Sekunden.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct IconTile: View {
    let choice: AppIconChoice
    let isSelected: Bool
    let dark: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = AppIconManager.image(for: choice, dark: dark) {
                            Image(nsImage: image).resizable().interpolation(.high)
                        } else {
                            RoundedRectangle(cornerRadius: 20).fill(.quaternary)
                        }
                    }
                    .frame(width: 88, height: 88)
                    .scaleEffect(hovering && !isSelected ? 1.05 : 1)
                    .padding(8)
                    .background {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .background(Circle().fill(.background).padding(2))
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(choice.title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .accessibilityLabel("App-Icon \(choice.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

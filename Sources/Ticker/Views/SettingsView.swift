import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"
    let model: AppModel

    var body: some View {
        TabView {
            Tab("Window", systemImage: "macwindow") { WindowSettings(model: model) }
            Tab("Shortcuts", systemImage: "keyboard") { ShortcutSettings(model: model) }
            Tab("General", systemImage: "gearshape") { CounterSettings(model: model) }
            Tab("App Icon", systemImage: "app.badge") { AppIconSettings(model: model) }
        }
        .frame(width: 540, height: 580)
        .navigationTitle("Ticker Settings")
        .environment(\.locale, model.settings.language.locale)
    }
}

// MARK: - Window

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
                Picker("Selected", selection: $settings.position) {
                    ForEach(OverlayPosition.allCases) { Text($0.title).tag($0) }
                }
                Picker("Display", selection: $settings.screen) {
                    ForEach(ScreenChoice.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Appearance") {
                Picker("Text color", selection: $settings.textColor) {
                    ForEach(TextColorMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Glass", selection: $settings.glassStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Size") {
                    HStack {
                        Slider(value: $settings.sizeScale, in: 0.4...1.6, step: 0.05) { editing in
                            if !editing { model.overlay?.preview() }
                        }
                        sizeDescription.monospacedDigit().foregroundStyle(.secondary).lineLimit(1).fixedSize().frame(minWidth: 64, alignment: .trailing)
                    }
                }
                LabeledContent("Aspect ratio") {
                    HStack {
                        Slider(value: $settings.aspectRatio, in: 1.0...3.0, step: 0.1) { editing in
                            if !editing { model.overlay?.preview() }
                        }
                        Text(String(format: "%.1f : 1", settings.aspectRatio)).monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                    }
                }
                LabeledContent("Edge margin") {
                    HStack {
                        Slider(value: $settings.screenMargin, in: 0...80, step: 2)
                        Text(verbatim: "\(Int(settings.screenMargin)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                    }
                }
            }

            Section("Visibility") {
                Picker("Show", selection: $settings.visibility) {
                    ForEach(VisibilityMode.allCases) { Text($0.title).tag($0) }
                }
                if settings.visibility == .flash {
                    LabeledContent("Display duration") {
                        HStack {
                            Slider(value: $settings.flashDuration, in: 0.5...10, step: 0.5)
                            Text(String(format: "%.1f s", settings.flashDuration)).monospacedDigit().foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                        }
                    }
                }
                Button("Show preview") { model.overlay?.preview() }
            }
        }
        .formStyle(.grouped)
    }

    private var sizeDescription: Text {
        settings.sizeScale == 1 ? Text("¼ height") : Text(verbatim: String(format: "%.0f %%", model.settings.sizeScale * 100))
    }

    private var settings: AppSettings { model.settings }
}

// MARK: - Shortcuts

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
                Text("Global shortcuts")
            } footer: {
                Text("Click a shortcut and press the new combination. For modifier-only shortcuts (e.g. ⌃⇧), press the keys together and release them. They fire on release if no other key was pressed in between. Esc cancels.")
                    .foregroundStyle(.secondary)
            }

            Section("Permission") {
                if model.hotkeys.isAccessibilityTrusted {
                    Label("Accessibility access granted", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Label {
                        Text(model.hotkeys.needsAccessibility
                             ? "Modifier-only shortcuts like ⌃⇧ need Accessibility access."
                             : "Only needed for modifier-only shortcuts like ⌃⇧.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    HStack {
                        Button("Request access") { model.hotkeys.requestAccessibility() }
                        Button("Open System Settings") { model.hotkeys.openAccessibilitySettings() }
                    }
                    .buttonStyle(.glass)
                }
            }

            Section {
                Button("Restore default shortcuts") { model.settings.hotkeys = Hotkey.defaults }
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

// MARK: - General

private struct CounterSettings: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Counter") {
                LabeledContent("Current count") {
                    TextField("", value: Binding(get: { model.counter.value }, set: { model.set($0) }), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                Stepper("Step size: \(settings.step)", value: $settings.step, in: 1...1000)
                LabeledContent("Start value (reset)") {
                    TextField("", value: $settings.startValue, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                Toggle("Allow negative values", isOn: $settings.allowNegative)
                Toggle("Click sound when counting", isOn: $settings.playSound)
            }

            Section {
                Picker("Language", selection: $settings.language) {
                    Text("System (\(AppLanguage.system.nativeName))").tag(AppLanguage.system)
                    Divider()
                    ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                        Text(verbatim: language.nativeName).tag(language)
                    }
                }
            } header: {
                Text("Language")
            } footer: {
                Text("By default Ticker uses your Mac’s language. Languages without a translation fall back to English.")
                    .foregroundStyle(.secondary)
            }

            Section("App") {
                Toggle("Show count in menu bar", isOn: $settings.showCountInMenuBar)
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.launchAtLogin = $0 }
                ))
            }

            Section {
                Button("Reset all settings", role: .destructive) { model.settings.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - App Icon

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
                Text("App Icon")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let error = model.appIconError {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Text("“Tile” is rendered live by macOS in Liquid Glass and adapts to every icon style. The other icons are applied as images that match your current light or dark icon style. Finder and the Applications folder update after a few seconds.")
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
        .accessibilityLabel(Text("App icon \(Text(choice.title))"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

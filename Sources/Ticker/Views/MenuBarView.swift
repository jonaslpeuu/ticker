import SwiftUI

/// The popover that opens from the menu bar item.
struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var settings = model.settings

        VStack(spacing: 14) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    roundButton("minus") { model.change(by: -settings.step) }
                        .help("Count down")

                    Text(verbatim: "\(model.counter.value)")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(model.counter.value)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))

                    roundButton("plus") { model.change(by: settings.step) }
                        .help("Count up")
                }
            }

            HStack {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    model.set(settings.startValue)
                }
                Spacer()
                Toggle("Show", isOn: Binding(
                    get: { model.overlay?.isVisible ?? false },
                    set: { model.overlay?.setPinned($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .help("Show the counter window")
            }
            .buttonStyle(.glass)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 6) {
                Text("Position: \(Text(settings.position.title))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PositionPicker(selection: $settings.position, compact: true) {
                    model.overlay?.preview()
                }
                .frame(height: 120)
            }

            shortcutsSummary

            Divider()

            HStack {
                Button("Settings…", systemImage: "gearshape") {
                    openWindow(id: SettingsView.windowID)
                    NSApp.activate()
                }
                .keyboardShortcut(",")
                Spacer()
                Button("Quit", systemImage: "power") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 300)
        .environment(\.locale, model.settings.language.locale)
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private var shortcutsSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(HotkeyAction.allCases) { action in
                if let hotkey = model.settings.hotkeys[action] {
                    HStack {
                        Label(action.title, systemImage: action.symbol)
                        Spacer()
                        Text(hotkey.displayString)
                    }
                }
            }
            if model.hotkeys.needsAccessibility && !model.hotkeys.isAccessibilityTrusted {
                Button {
                    model.hotkeys.requestAccessibility()
                } label: {
                    Label("Allow Accessibility access for ⌃⇧ shortcuts", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

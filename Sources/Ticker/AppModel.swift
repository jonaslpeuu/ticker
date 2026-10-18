import AppKit
import Observation
import ServiceManagement
import SwiftUI

/// Wires settings, counter, overlay and hotkeys together. Single instance for the app lifetime.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let settings = AppSettings()
    let counter = Counter()
    let hotkeys = HotkeyManager.shared
    @ObservationIgnored private(set) var overlay: OverlayController!

    private init() {}

    /// Called once from `applicationDidFinishLaunching`.
    func start() {
        guard overlay == nil else { return }
        overlay = OverlayController(settings: settings, counter: counter)
        settings.onChange = { [weak self] in self?.overlay.settingsDidChange() }
        settings.onHotkeysChange = { [weak self] in
            guard let self else { return }
            self.hotkeys.apply(self.settings.hotkeys)
        }
        if DemoStage.isActive {
            DemoStage.start(model: self)
            return
        }
        hotkeys.handler = { [weak self] action in self?.perform(action) }
        hotkeys.apply(settings.hotkeys)
        if hotkeys.needsAccessibility && !hotkeys.isAccessibilityTrusted {
            hotkeys.requestAccessibility()
        }
        enableLaunchAtLoginOnFirstInstall()
    }

    /// Launch at login is on by default: the first time Ticker runs from /Applications it
    /// registers itself as a login item. Afterwards the user's toggle in the settings wins.
    private func enableLaunchAtLoginOnFirstInstall() {
        let key = "launchAtLoginConfigured"
        guard !UserDefaults.standard.bool(forKey: key),
              Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        launchAtLogin = true
        UserDefaults.standard.set(true, forKey: key)
    }

    func perform(_ action: HotkeyAction) {
        switch action {
        case .increment: change(by: settings.step)
        case .decrement: change(by: -settings.step)
        case .reset: set(settings.startValue)
        case .show: overlay.toggle()
        }
    }

    func change(by delta: Int) {
        var next = counter.value + delta
        if !settings.allowNegative { next = max(0, next) }
        set(next)
    }

    func set(_ value: Int) {
        guard value != counter.value else {
            overlay.valueDidChange()
            return
        }
        withAnimation(.snappy(duration: 0.28)) { counter.value = value }
        if settings.playSound { NSSound(named: "Tink")?.play() }
        overlay.valueDidChange()
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get {
            access(keyPath: \.launchAtLoginToken)
            return SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Ticker: launch at login failed: \(error)")
            }
            withMutation(keyPath: \.launchAtLoginToken) { launchAtLoginToken += 1 }
        }
    }

    private var launchAtLoginToken = 0
}

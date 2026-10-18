import AppKit
import SwiftUI

@main
struct TickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Ticker Settings", id: SettingsView.windowID) {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
        .defaultLaunchBehavior(.suppressed)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon even when run without the bundle's LSUIElement.
        NSApp.setActivationPolicy(.accessory)
        MainActor.assumeIsolated { AppModel.shared.start() }
    }
}

private struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        if model.settings.showCountInMenuBar {
            Text(verbatim: "\(model.counter.value)")
                .monospacedDigit()
        } else {
            Image(systemName: "number.circle.fill")
        }
    }
}

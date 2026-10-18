# AGENTS.md — Guide for AI / human engineers

Ticker is a menu-bar-only macOS app (SwiftUI + AppKit, Swift 6, macOS 26+) that shows a counter in a floating Liquid Glass panel and changes it via global hotkeys. User-facing strings are **German**; code, comments and identifiers are **English**.

## Build / run / verify

```bash
scripts/install.sh                      # release build, signs with Apple Development cert, installs to /Applications, launches
scripts/build-app.sh release --run      # builds dist/Ticker.app (ad hoc unless TICKER_SIGN_IDENTITY), launches
scripts/make-dmg.sh                     # universal (arm64+x86_64) app, ad hoc signed, dist/Ticker-<version>.dmg via dmgbuild
scripts/screenshots.sh [scene]          # regenerates docs/images/*.png via demo mode (needs Screen Recording permission)
swift build --scratch-path ~/Library/Caches/Ticker-build   # compile check only
```

- **Always pass `--scratch-path` outside the repo.** A repo path containing spaces or a `"` breaks SwiftPM's linker file list (`clang: no such file or directory …`). Swift compilation itself is fine. The build script handles this for you.
- No Xcode project. The SwiftPM executable target is wrapped into an `.app` by `scripts/build-app.sh` using `Resources/Info.plist` (`LSUIElement = true`, bundle id `local.ticker.Ticker`).
- **Demo mode** (`Demo/DemoStage.swift`): `Ticker --demo overlay|settings|menu [--backdrop dark|light] [-<prefKey> <value> …]` shows a generated full-screen sample backdrop above normal windows and below the overlay, and skips hotkeys and the login item. Preferences are overridden through the argument domain (read, never written). `BackgroundSampler` reports the backdrop brightness while demo mode is active. `scripts/screenshots.sh` drives it, and `scripts/window-info.swift` finds window bounds.
- **Release DMG**: `scripts/make-dmg.sh` installs `dmgbuild` into a venv in the build cache and uses `scripts/dmg-settings.py`. The background (`Resources/dmg-background.tiff`, 1x+2x) is drawn by `scripts/make-dmg-background.swift`. It is intentionally minimal: plain white, a grey arrow and one English hint line. Keep it that way. Icon positions in both files must match. The version comes from `CFBundleShortVersionString` in `Resources/Info.plist`. Release builds are signed ad hoc, so no personal certificate is embedded. They are not notarized, which means users must click "Open Anyway" once.
- To release: bump the version in `Info.plist` and `CHANGELOG.md`, run `scripts/make-dmg.sh`, tag `vX.Y.Z`, then `gh release create vX.Y.Z dist/Ticker-X.Y.Z.dmg`.
- No test target yet. Verify by building, launching, and checking the behaviour by hand. `defaults read local.ticker.Ticker` shows the persisted state. Window placement can be checked without screen-recording permission via `CGWindowListCopyWindowInfo` (owner name `Ticker`).
- After changing the binary, macOS may drop the Accessibility grant (ad-hoc signature changes). If modifier-only hotkeys stop working, remove Ticker from System Settings → Privacy & Security → Accessibility and add it again. Set `TICKER_SIGN_IDENTITY` to a real identity to avoid this.

## Architecture

```
Sources/Ticker/
├── TickerApp.swift            @main: MenuBarExtra(.window) + settings Window scene; AppDelegate calls AppModel.start()
├── AppModel.swift             Singleton glue: owns AppSettings, Counter, OverlayController, HotkeyManager; perform(action)
├── Models/
│   ├── AppSettings.swift      @Observable prefs, each property persisted to UserDefaults in didSet → onChange / onHotkeysChange
│   ├── Counter.swift          @Observable counter value (UserDefaults "counterValue")
│   └── Hotkey.swift           Hotkey (keyCode? + modifiers), HotkeyAction, labels, Carbon modifier mapping, defaults
├── Services/
│   ├── HotkeyManager.swift    Carbon RegisterEventHotKey for key combos + NSEvent flagsChanged monitors for modifier-only combos
│   └── BackgroundSampler.swift Wallpaper luminance under a rect (for auto text color), cached
├── Demo/
│   └── DemoStage.swift         Screenshot/demo mode with a sample backdrop (see above)
├── Overlay/
│   ├── OverlayController.swift NSPanel (borderless, non-activating, click-through, all Spaces) hosting NSGlassEffectView
│   └── OverlayView.swift       SwiftUI number view inside the glass
└── Views/
    ├── MenuBarView.swift       Menu bar popover (counter, ± buttons, position picker, shortcut summary)
    ├── SettingsView.swift      Tabs: Fenster / Tastenkürzel / Zähler (Form, .grouped)
    ├── PositionPicker.swift    3×3 mini-screen picker
    └── HotkeyRecorder.swift    Click-to-record shortcut control (pauses HotkeyManager while recording)
```

### Data flow

- Every `AppSettings` property's `didSet` writes to UserDefaults and calls `onChange`. `AppModel` connects that to `OverlayController.settingsDidChange()`, which re-lays out the panel. Hotkey changes call `onHotkeysChange`, which re-registers everything.
- Every counter change goes through `AppModel.set(_:)` / `change(by:)`, which clamps (`allowNegative`), animates, plays the optional sound and calls `overlay.valueDidChange()`. **Don't mutate `counter.value` directly from UI.** Go through `AppModel`, otherwise the overlay won't flash.
- `OverlayController` visibility: `pinned` means shown persistently. `flash()` shows it and auto-hides after `flashDuration` unless pinned. `toggle()` is the "show" hotkey. The meaning depends on `VisibilityMode`.

### Key decisions / gotchas

- **Liquid Glass is Apple's real material**: `NSGlassEffectView` (`style` `.regular` / `.clear`, `cornerRadius`). The SwiftUI content goes in `glass.contentView`. Don't add arbitrary subviews to the glass view (Apple's docs say their z-order is undefined). The panel is `inset` (14 pt) bigger than the glass so the edge highlights aren't clipped. The panel's `appearance` is set to dark or light to match the text color, so the glass tint follows.
- **Overlay size** = `screen.frame.height / 4 * sizeScale`, width = height × `aspectRatio`, clamped to the visible frame. Positioning uses `visibleFrame` (excludes the menu bar and Dock) plus `screenMargin`.
- **Hotkeys**
  - Key combos: Carbon `RegisterEventHotKey`. No permission needed, and the event is consumed system-wide.
  - Modifier-only (`keyCode == nil`): global and local `NSEvent` monitors. Needs Accessibility (`AXIsProcessTrusted`). The action fires on **release** if the held set equals the binding exactly, nothing interrupted (key, click, scroll, or a Carbon hotkey firing, see `sequenceInterrupted`), and the press lasted ≤ 1 s. Monitors created before trust is granted stay deaf, so `startTrustPolling()` re-installs them once access arrives.
  - The recorder requires ≥ 2 modifiers for modifier-only combos and ≥ 1 modifier for key combos (except F-keys).
  - The Carbon callback is a global C function and hops to the main actor with `MainActor.assumeIsolated`. Carbon delivers on the main thread.
- **Auto text color** samples the wallpaper image only (`NSWorkspace.desktopImageURL`), so it needs no Screen Recording permission. It falls back to the system appearance and is cached per wallpaper and rect. The cache is invalidated on screen-parameter and theme changes.
- **Launch at login is on by default**: `AppModel.enableLaunchAtLoginOnFirstInstall()` registers `SMAppService.mainApp` once (flag `launchAtLoginConfigured`), and only when running from `/Applications`, so dev builds in `dist/` don't become login items. After that the settings toggle wins.
- Swift 6 strict concurrency: all app types are `@MainActor`. Closures from AppKit (NSEvent monitors, timers, notifications) use `MainActor.assumeIsolated`.

## Conventions

- Keep German UI copy short and consistent ("Hochzählen", "Runterzählen", "Fenster", "Tastenkürzel", "Zähler").
- New preferences: add a property to `AppSettings` with a `didSet { store(...) }`, a default in `register(defaults:)`, the key in `resetToDefaults()`, and UI in `SettingsView`.
- New hotkey actions: add a case to `HotkeyAction` (title and symbol) and handle it in `AppModel.perform`. Settings UI and the menu summary pick it up automatically.
- Prefer system components and Liquid Glass APIs (`.glassEffect`, `.buttonStyle(.glass)`, `GlassEffectContainer`, `NSGlassEffectView`) over custom blur.

## Ideas / open work

- Multiple named counters (switch via menu or hotkey) and a history/log with timestamps, with CSV export.
- Unit tests for `Hotkey` encoding and the modifier-only state machine (extract it from `HotkeyManager` into a pure struct).
- Use ScreenCaptureKit for true "what's behind the window" luminance (needs a permission flow).
- Proper Developer ID signing and notarization, plus Sparkle updates.
- Localization (`Localizable.xcstrings`) beyond German.

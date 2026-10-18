# Changelog

## 1.1.0 (2026-10-18)

- New app icon built with Icon Composer. macOS renders it live in Liquid Glass and in every icon style (default, dark, clear, tinted).
- Settings → App Icon: choose between four icons (Tile, Plus One, Tally, Roller)
- Localized into English, German, French, Spanish, Italian, Japanese and Simplified Chinese. Ticker follows the Mac’s language (English fallback), or you can pick one in Settings → General, and the switch takes effect live.
- Settings tab “Zähler” is now “General” and holds the language picker
- Menu bar panel: the visibility toggle label no longer wraps

## 1.0.0 (2026-10-18)

First public release.

- Menu bar counter with a floating panel in Apple's Liquid Glass (`NSGlassEffectView`)
- 9 panel positions (default: top right), size ¼ of the screen height, adjustable scale, aspect ratio and margin
- Automatic, white or black text color; *Regular* or *Clear* glass
- Global shortcuts you can change, including modifiers-only combos (`⌃⇧`)
- Visibility modes: flash on change, always visible, shortcut only
- Launch at login by default when installed to `/Applications`
- Demo mode and scripts for reproducible README screenshots
- Universal (Apple silicon + Intel) DMG installer with a drag-to-Applications window

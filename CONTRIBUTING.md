# Contributing to Ticker

Thanks for helping! Ticker is intentionally small, so focused pull requests are easiest to review.

## Getting started

1. You need macOS 26 or newer and Xcode 26 or newer (Swift 6.2).
2. Build and run with `scripts/build-app.sh debug --run`.
3. Read **[AGENTS.md](AGENTS.md)** first. It explains the architecture, the data flow and the non-obvious parts: the hotkey state machine, the glass panel, demo mode, and why build products live outside the repo.

## Guidelines

- Use Swift 6 with strict concurrency. App types are `@MainActor`.
- Prefer Apple's own components and Liquid Glass APIs over custom drawing.
- User-facing text is currently German. Code, comments and commit messages are English. Contributions that add localization (`Localizable.xcstrings`) are very welcome.
- If you change the UI, regenerate the screenshots with `scripts/screenshots.sh` (this needs Screen Recording permission for your terminal).
- Keep `README.md`, `README.de.md` and `AGENTS.md` up to date with your change.

## Reporting bugs

Please include your macOS version, your display setup, and your shortcut settings. Mention whether Accessibility permission is granted.

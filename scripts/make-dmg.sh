#!/usr/bin/env bash
# Builds dist/Ticker-<version>.dmg: universal app, Liquid Glass background, drag-to-Applications.
#   scripts/make-dmg.sh
# The app inside is signed ad hoc (set TICKER_SIGN_IDENTITY for a Developer ID). Without a
# Developer ID + notarization, users have to allow the first launch in System Settings.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${TICKER_BUILD_DIR:-$HOME/Library/Caches/Ticker-build}"
VENV="$CACHE/dmg-venv"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$ROOT/dist/Ticker-$VERSION.dmg"

if [ ! -x "$VENV/bin/dmgbuild" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet dmgbuild
fi
[ -f "$ROOT/Resources/dmg-background.tiff" ] || swift "$ROOT/scripts/make-dmg-background.swift"

TICKER_UNIVERSAL=1 TICKER_SIGN_IDENTITY="${TICKER_SIGN_IDENTITY:--}" "$ROOT/scripts/build-app.sh" release
lipo -info "$ROOT/dist/Ticker.app/Contents/MacOS/Ticker"

rm -f "$DMG"
"$VENV/bin/dmgbuild" -s "$ROOT/scripts/dmg-settings.py" \
  -D app="$ROOT/dist/Ticker.app" -D root="$ROOT" "Ticker $VERSION" "$DMG"
codesign --force --sign "${TICKER_SIGN_IDENTITY:--}" "$DMG"
shasum -a 256 "$DMG"
echo "Built $DMG"

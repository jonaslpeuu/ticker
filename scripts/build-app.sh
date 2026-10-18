#!/usr/bin/env bash
# Builds Ticker.app into ./dist (release by default).
#   scripts/build-app.sh            # release build
#   scripts/build-app.sh debug      # debug build
#   scripts/build-app.sh release --run   # build and launch
set -euo pipefail

CONFIG="${1:-release}"
RUN="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The repo path may contain spaces/quotes, which break SwiftPM's linker file lists,
# so build products live outside the repo.
SCRATCH="${TICKER_BUILD_DIR:-$HOME/Library/Caches/Ticker-build}"
APP="$ROOT/dist/Ticker.app"

# TICKER_UNIVERSAL=1 builds for Apple silicon and Intel (used for release DMGs).
ARCH_ARGS=()
if [ "${TICKER_UNIVERSAL:-0}" = 1 ]; then ARCH_ARGS=(--arch arm64 --arch x86_64); fi

cd "$ROOT"
swift build -c "$CONFIG" --scratch-path "$SCRATCH" "${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}"
BIN="$(swift build -c "$CONFIG" --scratch-path "$SCRATCH" "${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}" --show-bin-path)/Ticker"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ticker"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature. Note: macOS ties Accessibility permission to the signature, so after a
# rebuild you may need to re-enable Ticker under Privacy & Security → Accessibility.
codesign --force --sign "${TICKER_SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"

if [ "$RUN" = "--run" ]; then
  pkill -x Ticker 2>/dev/null || true
  open "$APP"
fi

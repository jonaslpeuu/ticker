#!/usr/bin/env bash
# Regenerates the README screenshots in docs/images using the app's demo mode
# (sample backdrop, nothing on your system is changed).
# Needs Screen Recording permission for the terminal/app running this script.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/images"
BIN="$ROOT/dist/Ticker.app/Contents/MacOS/Ticker"
WININFO="$ROOT/scripts/window-info.swift"
mkdir -p "$OUT"

[ -x "$BIN" ] || "$ROOT/scripts/build-app.sh" release

WAS_RUNNING=0
if pgrep -x Ticker >/dev/null; then WAS_RUNNING=1; pkill -x Ticker; sleep 1; fi

# Screen size in points (top-left origin), e.g. "1920 1080"
read -r SW SH < <(swift "$WININFO" screen)

ONLY="${1:-}"   # optional: regenerate a single scene, e.g. scripts/screenshots.sh hero

run_scene() { # name, then args for Ticker
  local name="$1"; shift
  if [ -n "$ONLY" ] && [ "$ONLY" != "$name" ]; then return; fi
  "$BIN" "$@" >/dev/null 2>&1 &
  local pid=$!
  sleep 3.5
  case "$name" in
    hero)
      # Whole screen below the menu bar, above the Dock.
      screencapture -x -R"0,40,$SW,$((SH * 74 / 100))" "$OUT/$name.png" ;;
    center-light)
      local w=$((SW * 60 / 100)) h=$((SH * 60 / 100))
      screencapture -x -R"$(((SW - w) / 2)),$(((SH - h) / 2)),$w,$h" "$OUT/$name.png" ;;
    settings|menu)
      # Frontmost Ticker window above the backdrop, plus a margin of backdrop around it.
      read -r x y w h < <(swift "$WININFO" ticker-top)
      local m=50 top=50
      # The menu panel hangs right below the menu bar: start below it, so the (system language) clock stays out.
      [ "$name" = menu ] && top=0
      screencapture -x -R"$((x - m)),$((y - top)),$((w + 2 * m)),$((h + top + m))" "$OUT/$name.png" ;;
  esac
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  echo "  → $OUT/$name.png"
}

# UI language for the screenshots (English by default, e.g. SHOT_LANG=de scripts/screenshots.sh)
SHOT_LANG="${SHOT_LANG:-en}"
COMMON=(-language "$SHOT_LANG" -AppleLanguages "($SHOT_LANG)" -visibility always -textColor auto -sizeScale 1 -aspectRatio 1.6 -glassStyle regular -screenMargin 16 -showCountInMenuBar 1)

echo "Capturing screenshots…"
run_scene hero         --demo overlay --backdrop dark  "${COMMON[@]}" -position topRight -counterValue 42
run_scene center-light --demo overlay --backdrop light "${COMMON[@]}" -position center   -counterValue 1337
run_scene settings     --demo settings --backdrop dark "${COMMON[@]}" -position topRight -counterValue 42 -visibility flash
run_scene menu         --demo menu    --backdrop light "${COMMON[@]}" -position topRight -counterValue 42 -visibility flash

if [ "$WAS_RUNNING" = 1 ]; then
  open "/Applications/Ticker.app" 2>/dev/null || open "$ROOT/dist/Ticker.app"
fi
echo "Done."

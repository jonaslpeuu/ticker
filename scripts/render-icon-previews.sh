#!/usr/bin/env bash
# Renders Resources/Icons/<id>-light.png and -dark.png from the .icon documents, exactly as macOS
# draws them (real Liquid Glass). The app uses these PNGs for the icon picker and for
# alternative icons. Re-run after changing scripts/make-icons.swift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TICKER_BUILD_DIR:-$HOME/Library/Caches/Ticker-build}/icon-previews"
rm -rf "$WORK"; mkdir -p "$WORK"
swiftc -O "$ROOT/scripts/render-icon.swift" -o "$WORK/render-icon"

for icon in "$ROOT"/Resources/Icons/*.icon; do
  id="$(basename "$icon" .icon)"
  app="$WORK/$id.app/Contents"
  mkdir -p "$app/Resources" "$app/MacOS"
  xcrun actool "$icon" --compile "$app/Resources" --app-icon "$id" --platform macosx \
    --minimum-deployment-target 26.0 --output-partial-info-plist "$WORK/$id.plist" >/dev/null
  # A runnable-looking bundle, otherwise the system draws a "prohibited" badge.
  cp /usr/bin/true "$app/MacOS/preview"
  cat > "$app/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.ticker.iconpreview.$id.$RANDOM</string>
<key>CFBundleExecutable</key><string>preview</string>
<key>CFBundleIconName</key><string>$id</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
  codesign --force --sign - "$WORK/$id.app" 2>/dev/null
  for style in Light Dark; do
    lower="$(echo "$style" | tr '[:upper:]' '[:lower:]')"
    "$WORK/render-icon" "$WORK/$id.app" "$ROOT/Resources/Icons/$id-$lower.png" -AppleIconAppearanceTheme "Regular$style"
  done
  echo "  $id"
done

#!/usr/bin/env bash
# Builds a release Ticker.app, installs it to /Applications and starts it.
# On its first run from /Applications, Ticker registers itself to launch at login.
#
# Signing: uses the first "Apple Development" identity found (stable signature, so the
# Accessibility permission survives updates). Override with TICKER_SIGN_IDENTITY, "-" = ad hoc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Ticker.app"

if [ -z "${TICKER_SIGN_IDENTITY:-}" ]; then
  TICKER_SIGN_IDENTITY="$(security find-identity -v -p codesigning \
    | awk '/Apple Development/ { print $2; exit }')"
  TICKER_SIGN_IDENTITY="${TICKER_SIGN_IDENTITY:--}"
fi
export TICKER_SIGN_IDENTITY
echo "Signing with: $TICKER_SIGN_IDENTITY"

"$ROOT/scripts/build-app.sh" release

pkill -x Ticker 2>/dev/null || true
sleep 0.5
rm -rf "$DEST"
cp -R "$ROOT/dist/Ticker.app" "$DEST"
open "$DEST"
echo "Installed $DEST"

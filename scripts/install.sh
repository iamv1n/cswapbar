#!/usr/bin/env bash
# Build CSwapBar and install it to /Applications (or $INSTALL_DIR).
# A locally built app has no quarantine flag, so Gatekeeper won't prompt.
set -euo pipefail

cd "$(dirname "$0")/.."

INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP="build/CSwapBar.app"

if ! command -v cswap >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/cswap" ]]; then
    echo "warning: cswap not found. Install it first: uv tool install claude-swap" >&2
fi

./scripts/build.sh

if pgrep -xq CSwapBar; then
    echo "==> Quitting running CSwapBar"
    osascript -e 'quit app "CSwapBar"' 2>/dev/null || pkill -x CSwapBar || true
    sleep 1
fi

echo "==> Installing to ${INSTALL_DIR}"
rm -rf "${INSTALL_DIR}/CSwapBar.app"
ditto "$APP" "${INSTALL_DIR}/CSwapBar.app"

echo "==> Launching"
open "${INSTALL_DIR}/CSwapBar.app"
echo "Done. CSwapBar is in your menu bar."

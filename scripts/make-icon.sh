#!/usr/bin/env bash
# Regenerate the app icon and README logo from the SwiftUI drawing in
# Sources/CSwapBarApp/DesignSystem/LogoMark.swift.
#
#   ./scripts/make-icon.sh   →  Support/AppIcon.icns, docs/images/logo.png
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --product CSwapBar >/dev/null
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$(swift build --show-bin-path)/CSwapBar" --render-logo "$TMP"
iconutil -c icns "$TMP/AppIcon.iconset" -o Support/AppIcon.icns
mkdir -p docs/images
cp "$TMP/logo.png" docs/images/logo.png
echo "==> Support/AppIcon.icns, docs/images/logo.png"

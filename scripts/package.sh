#!/usr/bin/env bash
# Package build/CSwapBar.app for GitHub Releases: a DMG (drag-to-Applications)
# and a zip, each with a SHA-256 checksum.
#
#   ./scripts/package.sh                 # version from the VERSION file
#   VERSION=0.2.0-beta.1 ./scripts/package.sh
#   → dist/CSwapBar-<version>.dmg (+ .sha256)
#   → dist/CSwapBar-<version>.zip (+ .sha256)
#
# Uses only built-in macOS tools (hdiutil, ditto, shasum). The app is ad-hoc
# signed and not notarized, so users see a Gatekeeper prompt on first launch
# (System Settings → Privacy & Security → Open Anyway). See docs/INSTALL.md.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(tr -d '[:space:]' < VERSION)}"
export VERSION
NAME="CSwapBar-${VERSION}"

./scripts/build.sh

mkdir -p dist
rm -f "dist/${NAME}.dmg" "dist/${NAME}.zip" dist/"${NAME}".*.sha256

# ── Zip ──────────────────────────────────────────────────────────────────
echo "==> Zip"
ditto -c -k --keepParent build/CSwapBar.app "dist/${NAME}.zip"

# ── DMG ──────────────────────────────────────────────────────────────────
echo "==> DMG"
STAGING="$(mktemp -d)"
WORK="$(mktemp -d)"
trap 'rm -rf "$STAGING" "$WORK"' EXIT
ditto build/CSwapBar.app "$STAGING/CSwapBar.app"
ln -s /Applications "$STAGING/Applications"

# Short first-launch help, visible right next to the app.
cat > "$STAGING/If CSwapBar won't open.txt" <<'TXT'
CSwapBar isn't notarized by Apple (that needs a paid developer account),
so macOS blocks it the first time you open it. To allow it once:

macOS 15 Sequoia or later
  1. Drag CSwapBar to Applications and try to open it. Click "Done".
  2. Open System Settings > Privacy & Security.
  3. Under Security, click "Open Anyway" and enter your password.
  4. Click "Open Anyway" again.

macOS 14 Sonoma
  Right-click CSwapBar in Applications > Open > Open.

Any version (Terminal)
  xattr -dr com.apple.quarantine /Applications/CSwapBar.app

If macOS says the app "is damaged", use the Terminal command above.

Full guide: https://github.com/iamv1n/CSwapBar/blob/main/docs/INSTALL.md
CSwapBar needs CSwap installed:  uv tool install claude-swap
TXT

# Volume icon (shown in Finder's sidebar and on the desktop when mounted).
if [[ -f Support/AppIcon.icns ]]; then
    cp Support/AppIcon.icns "$STAGING/.VolumeIcon.icns"
fi

RW_DMG="$WORK/rw.dmg"
hdiutil create -quiet -volname "CSwapBar" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$RW_DMG"

# Mark the volume as having a custom icon (SetFile ships with the developer tools).
if [[ -f "$STAGING/.VolumeIcon.icns" ]] && command -v SetFile >/dev/null; then
    MOUNT="$(hdiutil attach -nobrowse -noautoopen "$RW_DMG" 2>/dev/null | awk -F'\t' '/Apple_HFS/ {print $NF}')"
    SetFile -a C "$MOUNT" || true
    hdiutil detach -quiet "$MOUNT"
fi

hdiutil convert -quiet "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "dist/${NAME}.dmg"
codesign --force --sign - "dist/${NAME}.dmg"
hdiutil verify -quiet "dist/${NAME}.dmg"

# ── Checksums ────────────────────────────────────────────────────────────
(cd dist && for f in "${NAME}.dmg" "${NAME}.zip"; do shasum -a 256 "$f" > "$f.sha256"; done)

echo "==> Release artifacts"
ls -lh "dist/${NAME}.dmg" "dist/${NAME}.zip" | awk '{print "    " $5 "\t" $NF}'
cat dist/"${NAME}".*.sha256 | sed 's/^/    /'

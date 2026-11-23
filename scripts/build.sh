#!/usr/bin/env bash
# Build CSwapBar.app into build/.
#
#   ./scripts/build.sh              # release build for this Mac's architecture
#   CONFIG=debug ./scripts/build.sh
#   UNIVERSAL=1 ./scripts/build.sh  # arm64 + x86_64 (needs Xcode)
#
# The app is ad-hoc signed: fine for running locally and for open-source
# releases without an Apple Developer account (see docs/INSTALL.md).
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="CSwapBar"
VERSION="${VERSION:-$(tr -d '[:space:]' < VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
BUNDLE_ID="${BUNDLE_ID:-io.github.iamv1n.CSwapBar}"
CONFIG="${CONFIG:-release}"

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "==> swift build (${CONFIG})"
swift build -c "$CONFIG" --product "$APP_NAME" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" --product "$APP_NAME" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="build/${APP_NAME}.app"
echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
sed -e "s|__BUNDLE_ID__|${BUNDLE_ID}|" \
    -e "s|__VERSION__|${VERSION}|" \
    -e "s|__BUILD__|${BUILD_NUMBER}|" \
    Support/Info.plist > "$APP/Contents/Info.plist"
plutil -lint -s "$APP/Contents/Info.plist"

if [[ -f Support/AppIcon.icns ]]; then
    cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    plutil -insert CFBundleIconFile -string AppIcon "$APP/Contents/Info.plist"
fi

echo "==> Ad-hoc signing"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "==> Built $(pwd)/${APP} (v${VERSION}, build ${BUILD_NUMBER})"

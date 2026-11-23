#!/usr/bin/env bash
# Install CSwapBar from source in one line:
#
#   curl -fsSL https://raw.githubusercontent.com/iamv1n/CSwapBar/main/scripts/get.sh | bash
#
# Clones (or updates) the repository into ~/.cswapbar/src, builds the app, and
# installs it to /Applications. Read this script before piping it to bash.
#
# Environment overrides:
#   CSWAPBAR_REPO   git URL      (default: https://github.com/iamv1n/CSwapBar.git)
#   CSWAPBAR_REF    branch/tag   (default: main)
#   CSWAPBAR_DIR    checkout dir (default: ~/.cswapbar/src)
#   INSTALL_DIR     where the .app goes (default: /Applications)
set -euo pipefail

REPO="${CSWAPBAR_REPO:-https://github.com/iamv1n/CSwapBar.git}"
REF="${CSWAPBAR_REF:-main}"
DIR="${CSWAPBAR_DIR:-$HOME/.cswapbar/src}"

[[ "$(uname -s)" == "Darwin" ]] || { echo "CSwapBar is a macOS app." >&2; exit 1; }
command -v git >/dev/null || { echo "git is required. Install the Command Line Tools: xcode-select --install" >&2; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Install the Command Line Tools first: xcode-select --install" >&2; exit 1; }

if [[ -d "$DIR/.git" ]]; then
    echo "==> Updating $DIR"
    git -C "$DIR" fetch --quiet origin "$REF"
    git -C "$DIR" checkout --quiet "$REF"
    git -C "$DIR" pull --quiet --ff-only origin "$REF"
else
    echo "==> Cloning $REPO into $DIR"
    mkdir -p "$(dirname "$DIR")"
    git clone --quiet --branch "$REF" --depth 1 "$REPO" "$DIR"
fi

cd "$DIR"
./scripts/setup.sh --skip-tests --install

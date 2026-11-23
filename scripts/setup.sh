#!/usr/bin/env bash
# One-command developer setup for CSwapBar.
#
#   ./scripts/setup.sh              # check tools, build, run tests
#   ./scripts/setup.sh --run        # …then launch a debug build
#   ./scripts/setup.sh --install    # …then build the .app and install it to /Applications
#   ./scripts/setup.sh --yes        # don't prompt (assume "yes" to installing missing CSwap)
#
# Other flags: --skip-tests, --skip-cswap, --help
#
# Safe to re-run. It never touches your Claude accounts: CSwap is only
# detected/installed, and the optional integration tests are read-only.
set -euo pipefail

cd "$(dirname "$0")/.."

# ── Options ────────────────────────────────────────────────────────────────
ASSUME_YES=0; RUN=0; INSTALL=0; SKIP_TESTS=0; SKIP_CSWAP=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        --run) RUN=1 ;;
        --install) INSTALL=1 ;;
        --skip-tests) SKIP_TESTS=1 ;;
        --skip-cswap) SKIP_CSWAP=1 ;;
        --help|-h) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

# ── Output helpers ─────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$'\e[1m'; DIM=$'\e[2m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; RESET=$'\e[0m'
else
    BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi
step() { printf "\n${BOLD}==> %s${RESET}\n" "$1"; }
ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}✗${RESET} %s\n" "$1" >&2; exit 1; }

confirm() {
    [[ $ASSUME_YES == 1 ]] && return 0
    [[ -t 0 ]] || return 1   # non-interactive: default to "no"
    read -r -p "  $1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Compare dotted versions: version_ge 6.1.2 6.0 → true
version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }

# ── 1. macOS ───────────────────────────────────────────────────────────────
step "macOS"
[[ "$(uname -s)" == "Darwin" ]] || fail "CSwapBar is a macOS app. This machine is $(uname -s)."
MACOS="$(sw_vers -productVersion)"
version_ge "$MACOS" "14.0" || fail "macOS 14 Sonoma or later is required (found $MACOS)."
ok "macOS $MACOS ($(uname -m))"

# ── 2. Developer tools ─────────────────────────────────────────────────────
step "Developer tools"
if ! DEV_DIR="$(xcode-select -p 2>/dev/null)"; then
    warn "No Xcode or Command Line Tools found."
    echo "    Install the Command Line Tools (about 1 GB), then re-run this script:"
    echo "      xcode-select --install"
    exit 1
fi
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
    ok "Command Line Tools ($DEV_DIR)"
    if [[ -d /Applications/Xcode.app ]]; then
        warn "Xcode is installed but not selected. Optional, for SwiftUI Previews and Instruments:"
        echo "      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    fi
else
    XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -1 || true)"
    if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
        warn "${XCODE_VERSION:-Xcode} needs its license accepted / first launch finished:"
        echo "      sudo xcodebuild -license accept && xcodebuild -runFirstLaunch"
        exit 1
    fi
    ok "${XCODE_VERSION:-Xcode} ($DEV_DIR)"
fi

command -v swift >/dev/null || fail "swift not found on PATH."
SWIFT_VERSION="$(swift --version 2>/dev/null | sed -nE 's/.*Swift version ([0-9]+(\.[0-9]+)*).*/\1/p' | head -1)"
[[ -n "$SWIFT_VERSION" ]] || fail "Couldn't read the Swift version."
version_ge "$SWIFT_VERSION" "6.0" || fail "Swift 6.0 or later is required (found $SWIFT_VERSION). Update Xcode or the Command Line Tools."
ok "Swift $SWIFT_VERSION"

# ── 3. CSwap ───────────────────────────────────────────────────────────────
step "CSwap (the CLI CSwapBar drives)"
find_cswap() {
    for candidate in "$(command -v cswap 2>/dev/null || true)" "$HOME/.local/bin/cswap" /opt/homebrew/bin/cswap /usr/local/bin/cswap; do
        [[ -n "$candidate" && -x "$candidate" ]] && { echo "$candidate"; return 0; }
    done
    return 1
}
if [[ $SKIP_CSWAP == 1 ]]; then
    warn "Skipped (--skip-cswap). The app will show setup instructions until CSwap is installed."
elif CSWAP="$(find_cswap)"; then
    CSWAP_VERSION="$("$CSWAP" --version 2>/dev/null | awk '{print $NF}')"
    if version_ge "${CSWAP_VERSION:-0}" "1.1.0"; then
        ok "cswap $CSWAP_VERSION ($CSWAP)"
    else
        warn "cswap ${CSWAP_VERSION:-unknown} is older than 1.1.0. Upgrade with: cswap upgrade"
    fi
else
    warn "cswap not found. CSwapBar needs it to show real accounts (unit tests don't)."
    if command -v uv >/dev/null && confirm "Install it now with 'uv tool install claude-swap'?"; then
        uv tool install claude-swap
        ok "Installed. Add your accounts later with: cswap add"
    elif command -v pipx >/dev/null && confirm "Install it now with 'pipx install claude-swap'?"; then
        pipx install claude-swap
        ok "Installed. Add your accounts later with: cswap add"
    else
        echo "    Install it yourself when ready:  uv tool install claude-swap   (or: pipx install claude-swap)"
    fi
fi

# ── 4. Optional tools ──────────────────────────────────────────────────────
step "Optional tools"
for tool in gh swiftformat swiftlint; do
    if command -v "$tool" >/dev/null; then ok "$tool"; else printf "  ${DIM}- %s (optional: brew install %s)${RESET}\n" "$tool" "$tool"; fi
done

# ── 5. Build & test ────────────────────────────────────────────────────────
step "Build"
BUILD_LOG="${TMPDIR:-/tmp}/cswapbar-setup-build.log"
if swift build > "$BUILD_LOG" 2>&1; then
    ok "Debug build: $(swift build --show-bin-path)/CSwapBar"
else
    grep -E "error:" "$BUILD_LOG" | sed -E 's/\x1b\[[0-9;]*m//g' | head -20 >&2 || true
    fail "Build failed (full log: $BUILD_LOG)."
fi

if [[ $SKIP_TESTS == 1 ]]; then
    step "Tests"; warn "Skipped (--skip-tests)."
else
    step "Tests"
    TEST_LOG="${TMPDIR:-/tmp}/cswapbar-setup-tests.log"
    if ./scripts/test.sh > "$TEST_LOG" 2>&1; then
        ok "$(grep -E "Test run with" "$TEST_LOG" | tail -1 | sed -E 's/\x1b\[[0-9;]*m//g; s/^[^A-Za-z]*//')"
    else
        tail -30 "$TEST_LOG" >&2
        fail "Tests failed (full log: $TEST_LOG)."
    fi
fi

# ── 6. Optional: run or install ────────────────────────────────────────────
if [[ $INSTALL == 1 ]]; then
    step "Install"
    ./scripts/install.sh
elif [[ $RUN == 1 ]]; then
    step "Run"
    "$(swift build --show-bin-path)/CSwapBar" &
    ok "Launched (pid $!). Look for the icon in your menu bar."
fi

# ── Done ───────────────────────────────────────────────────────────────────
cat <<EOF

${BOLD}${GREEN}Ready.${RESET} Next steps:
  swift run CSwapBar                          run the app from source
  ./scripts/test.sh                           unit tests
  CSWAPBAR_INTEGRATION=1 ./scripts/test.sh    + read-only tests against your real CSwap
  ./scripts/install.sh                        build the .app and install it to /Applications

  Development guide:  DEVELOPMENT.md
  Contributing:       CONTRIBUTING.md
EOF

#!/usr/bin/env bash
# Run the test suite. Works with full Xcode or Command Line Tools only.
#
#   ./scripts/test.sh                            # unit tests
#   CSWAPBAR_INTEGRATION=1 ./scripts/test.sh     # + read-only tests against your real CSwap
#   ./scripts/test.sh --filter Switching         # extra args go to `swift test`
set -euo pipefail

cd "$(dirname "$0")/.."

EXTRA=()
DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
    # CLT ships Swift Testing's macro plugin in a subfolder the compiler doesn't search.
    PLUGINS="$DEV_DIR/usr/lib/swift/host/plugins/testing"
    if [[ -d "$PLUGINS" ]]; then
        EXTRA=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS")
    fi
fi

swift test ${EXTRA[@]+"${EXTRA[@]}"} "$@"

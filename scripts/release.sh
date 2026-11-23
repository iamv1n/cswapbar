#!/usr/bin/env bash
# Cut a release: bump VERSION, date the CHANGELOG, commit, and tag.
#
#   ./scripts/release.sh 0.2.0
#   git push origin main --follow-tags
#   ./scripts/package.sh                    # → dist/CSwapBar-0.2.0.dmg, .zip, .sha256
#   Then create the GitHub Release by hand and attach the files from dist/.
#
# Requires a clean working tree on `main` and a non-empty "## [Unreleased]"
# section in CHANGELOG.md. Nothing is pushed; the last step is yours.
set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:-}"
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "Usage: $0 <semver>   e.g. 0.2.0 or 0.2.0-beta.1" >&2; exit 2; }
OLD="$(tr -d '[:space:]' < VERSION)"
TAG="v$NEW"
TODAY="$(date +%Y-%m-%d)"

[[ -z "$(git status --porcelain)" ]] || { echo "Working tree is not clean. Commit or stash first." >&2; exit 1; }
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "Releases are cut from main." >&2; exit 1; }
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "Tag $TAG already exists." >&2; exit 1; }
[[ "$(printf '%s\n%s\n' "$OLD" "$NEW" | sort -V | tail -1)" == "$NEW" && "$OLD" != "$NEW" ]] \
    || { echo "New version $NEW must be greater than $OLD." >&2; exit 1; }

# The Unreleased section must have content.
UNRELEASED="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -vE '^\s*$' || true)"
[[ -n "$UNRELEASED" ]] || { echo "CHANGELOG.md has nothing under ## [Unreleased]." >&2; exit 1; }

echo "==> $OLD → $NEW"
./scripts/test.sh >/dev/null

echo "$NEW" > VERSION
python3 -I - "$NEW" "$TODAY" <<'PY'
import sys, re
new, today = sys.argv[1], sys.argv[2]
path = "CHANGELOG.md"
text = open(path).read()
text = text.replace("## [Unreleased]", f"## [Unreleased]\n\n## [{new}] - {today}", 1)
# Compare links at the bottom.
text = re.sub(r"^\[Unreleased\]: (.*)/compare/v[^.\s]+\.[^.\s]+\.[^.\s]+\.\.\.HEAD$",
              lambda m: f"[Unreleased]: {m.group(1)}/compare/v{new}...HEAD\n[{new}]: {m.group(1)}/releases/tag/v{new}",
              text, count=1, flags=re.M)
open(path, "w").write(text)
PY

git add VERSION CHANGELOG.md
git commit -m "Release $TAG"
git tag -a "$TAG" -m "CSwapBar $NEW"

echo "==> Tagged $TAG. Next:"
echo "    git push origin main --follow-tags"
echo "    ./scripts/package.sh"
echo "    Create a GitHub Release for $TAG and attach dist/CSwapBar-$NEW.{dmg,zip} and their .sha256 files."

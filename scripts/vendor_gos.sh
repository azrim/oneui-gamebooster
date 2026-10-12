#!/usr/bin/env bash
# (Re)download the GOS builds from APKMirror and upload them to the "gos-vendor"
# release of this repo, so build.sh can fetch them from a source CI can reach.
#
# Usage: scripts/vendor_gos.sh [release-tag]     (default tag: gos-vendor)
#
# Bump the URLs below when you want newer GOS builds. Needs `gh` (authenticated).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-gos-vendor}"
GOS_AM="https://www.apkmirror.com/apk/samsung-electronics-co-ltd/game-optimizing-service"
MODERN_URL="${GOS_MODERN_URL:-$GOS_AM/samsung-game-optimizing-service-4-4-00-8-release/samsung-game-optimizing-service-4-4-00-8-android-apk-download/}"
LEGACY_URL="${GOS_LEGACY_URL:-$GOS_AM/samsung-game-optimizing-service-4-0-06-release/samsung-game-optimizing-service-4-0-06-android-apk-download/}"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "==> downloading GOS builds from APKMirror"
"$HERE/scripts/apkmirror.sh" "$MODERN_URL" "$tmp/gos-modern.apk"
"$HERE/scripts/apkmirror.sh" "$LEGACY_URL" "$tmp/gos-legacy.apk"

for f in "$tmp"/gos-*.apk; do
    pkg="$(python3 "$HERE/scripts/axml.py" "$f" | sed -n 's/^ *package=\([^ ]*\).*/\1/p' | head -1)"
    [ "$pkg" = "com.samsung.android.game.gos" ] || { echo "$f is not GOS ($pkg)" >&2; exit 1; }
done

echo "==> uploading to release '$TAG'"
gh release upload "$TAG" "$tmp/gos-modern.apk" "$tmp/gos-legacy.apk" --clobber
echo "done."

#!/usr/bin/env bash
# Samsung Game Booster - KernelSU/Magisk module builder.
#
# Fetches the Samsung gaming apps (gametools/gamehome from the Galaxy Store, GOS from
# this repo's "gos-vendor" release), generates the additive permission allowlists and
# packs the module zip.
#
# Env overrides: VERSION, VERSIONCODE, WORK, DIST, GS_DEVICES, REPO_SLUG,
#                GOS_VENDOR_BASE, GOS_MODERN_URL, GOS_LEGACY_URL, GOS_FALLBACK_URL
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/galaxy_store.sh
source "$REPO_DIR/scripts/galaxy_store.sh"

WORK="${WORK:-$REPO_DIR/.work}"
DIST="${DIST:-$REPO_DIR/dist}"
MOD_ID=samsung_gamebooster
VERSION="${VERSION:-$(date +%Y.%m.%d)}"
VERSIONCODE="${VERSIONCODE:-$(date +%y%m%d)}"

# Galaxy Store baseline (sdkVer, oneUiVersion) -> the app build Samsung serves
GT_MODERN_SDK=36; GT_MODERN_UI=80000   # gametools 8.x, API 35+
GT_LEGACY_SDK=33; GT_LEGACY_UI=50000   # gametools 5.x, API 30-34
GAMEHOME_SDK=36;  GAMEHOME_UI=80000

# GOS is a system component and is NOT on the Galaxy Store. APK mirrors sit behind
# Cloudflare and 403 datacenter IPs (incl. GitHub runners), so the two GOS builds are
# vendored as assets of the "gos-vendor" release in this repo. Mirrors are fallbacks.
SLUG="${REPO_SLUG:-$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null \
        | sed -E 's#(git@|https://)github\.com[:/]##; s#\.git$##')}"
[ -n "$SLUG" ] || SLUG="azrim/oneui-gamebooster"
GOS_VENDOR_BASE="${GOS_VENDOR_BASE:-https://github.com/$SLUG/releases/download/gos-vendor}"
GOS_AM="https://www.apkmirror.com/apk/samsung-electronics-co-ltd/game-optimizing-service"
GOS_MODERN_URL="${GOS_MODERN_URL:-$GOS_AM/samsung-game-optimizing-service-4-4-00-8-release/samsung-game-optimizing-service-4-4-00-8-android-apk-download/}"  # arm64, API 33+
GOS_LEGACY_URL="${GOS_LEGACY_URL:-$GOS_AM/samsung-game-optimizing-service-4-0-06-release/samsung-game-optimizing-service-4-0-06-android-apk-download/}"  # noarch, API 29+
GOS_FALLBACK_URL="${GOS_FALLBACK_URL:-https://d.apkpure.com/b/APK/com.samsung.android.game.gos?version=latest}"

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

apk_package() { python3 "$REPO_DIR/scripts/axml.py" "$1" 2>/dev/null | sed -n 's/^ *package=\([^ ]*\).*/\1/p' | head -1; }
verify_apk() { [ "$(apk_package "$1")" = "$2" ] || die "$(basename "$1") is not $2"; }
_gos_ok() { [ "$(apk_package "$1")" = "com.samsung.android.game.gos" ]; }

# fetch_gos <modern|legacy> <outfile> - vendored release -> APKMirror -> mirror
fetch_gos() {
    local kind="$1" out="$2" url
    if curl -fsSL --retry 2 --max-time 600 -o "$out" "$GOS_VENDOR_BASE/gos-$kind.apk" && _gos_ok "$out"; then
        echo "  source: vendored release"; return 0
    fi
    if [ "$kind" = modern ]; then url="$GOS_MODERN_URL"; else url="$GOS_LEGACY_URL"; fi
    if "$REPO_DIR/scripts/apkmirror.sh" "$url" "$out" && _gos_ok "$out"; then
        echo "  source: APKMirror"; return 0
    fi
    if [ "$kind" = legacy ] && curl -fsSL --retry 2 --max-time 600 \
            -A "Mozilla/5.0 (Linux; Android 14)" -o "$out" "$GOS_FALLBACK_URL" && _gos_ok "$out"; then
        echo "  source: mirror"; return 0
    fi
    return 1
}

for c in curl python3 zip; do command -v "$c" >/dev/null || die "$c not found"; done

rm -rf "$WORK"
mkdir -p "$WORK/apks" "$DIST"

log "Fetching Game Booster (modern, API 35+)  [$(gs_version_name com.samsung.android.game.gametools $GT_MODERN_SDK $GT_MODERN_UI 2>/dev/null || echo '?')]"
fetch_apk com.samsung.android.game.gametools "$GT_MODERN_SDK" "$GT_MODERN_UI" "$WORK/apks/gametools-modern.apk" \
    || die "could not fetch modern gametools"
verify_apk "$WORK/apks/gametools-modern.apk" com.samsung.android.game.gametools

log "Fetching Game Booster (legacy, API 30-34) [$(gs_version_name com.samsung.android.game.gametools $GT_LEGACY_SDK $GT_LEGACY_UI 2>/dev/null || echo '?')]"
fetch_apk com.samsung.android.game.gametools "$GT_LEGACY_SDK" "$GT_LEGACY_UI" "$WORK/apks/gametools-legacy.apk" \
    || die "could not fetch legacy gametools"
verify_apk "$WORK/apks/gametools-legacy.apk" com.samsung.android.game.gametools

log "Fetching Game Launcher"
fetch_apk com.samsung.android.game.gamehome "$GAMEHOME_SDK" "$GAMEHOME_UI" "$WORK/apks/gamehome.apk" \
    || die "could not fetch gamehome"
verify_apk "$WORK/apks/gamehome.apk" com.samsung.android.game.gamehome

log "Fetching GOS (modern, API 33+)"
GOS_MODERN=""
if fetch_gos modern "$WORK/apks/gos-modern.apk"; then GOS_MODERN="$WORK/apks/gos-modern.apk"; fi

log "Fetching GOS (legacy, API 29-32)"
GOS_LEGACY=""
if fetch_gos legacy "$WORK/apks/gos-legacy.apk"; then GOS_LEGACY="$WORK/apks/gos-legacy.apk"; fi

if [ -z "$GOS_MODERN" ] && [ -z "$GOS_LEGACY" ]; then
    warn "GOS unavailable from every source - building without it"
fi

log "Assembling module"
MOD="$WORK/$MOD_ID"
cp -a "$REPO_DIR/module" "$MOD"
mkdir -p "$MOD/apks" \
         "$MOD/system/priv-app/GameTools_Dream" \
         "$MOD/system/priv-app/GameOptimizationService" \
         "$MOD/system/app/GameHome" \
         "$MOD/system/etc/permissions"

cp "$WORK/apks/gametools-modern.apk" "$MOD/system/priv-app/GameTools_Dream/GameTools_Dream.apk"
cp "$WORK/apks/gametools-legacy.apk" "$MOD/apks/gametools-legacy.apk"
cp "$WORK/apks/gamehome.apk"         "$MOD/system/app/GameHome/GameHome.apk"

# GOS: modern is the default in system/, legacy goes to apks/ for customize.sh to swap in.
GOS_SYS=""
if [ -n "$GOS_MODERN" ]; then
    GOS_SYS="$GOS_MODERN"
elif [ -n "$GOS_LEGACY" ]; then
    GOS_SYS="$GOS_LEGACY"
fi
if [ -n "$GOS_SYS" ]; then
    cp "$GOS_SYS" "$MOD/system/priv-app/GameOptimizationService/GameOptimizationService.apk"
fi
if [ -n "$GOS_LEGACY" ]; then
    cp "$GOS_LEGACY" "$MOD/apks/gos-legacy.apk"
fi

log "Generating permission allowlists"
PRIVAPP_APKS=("$WORK/apks/gametools-modern.apk" "$WORK/apks/gametools-legacy.apk")
if [ -n "$GOS_MODERN" ]; then PRIVAPP_APKS+=("$GOS_MODERN"); fi
if [ -n "$GOS_LEGACY" ]; then PRIVAPP_APKS+=("$GOS_LEGACY"); fi
python3 "$REPO_DIR/scripts/gen_perms.py" \
    --priv-list "$REPO_DIR/data/privileged-permissions.txt" \
    --out "$MOD/system/etc/permissions" \
    --privapp "${PRIVAPP_APKS[@]}" \
    --signature "$WORK/apks/gamehome.apk"

sed -i "s|^version=.*|version=v${VERSION}|" "$MOD/module.prop"
sed -i "s|^versionCode=.*|versionCode=${VERSIONCODE}|" "$MOD/module.prop"

find "$MOD" -type d -exec chmod 0755 {} +
find "$MOD" -type f -exec chmod 0644 {} +
chmod 0755 "$MOD/customize.sh" "$MOD/META-INF/com/google/android/update-binary"

ZIP="$DIST/${MOD_ID}-v${VERSION}.zip"
rm -f "$ZIP"
( cd "$MOD" && zip -rq "$ZIP" . -x '.*' )

log "Built $(basename "$ZIP")  ($(du -h "$ZIP" | cut -f1))"
log "sha256: $(sha256sum "$ZIP" | cut -d' ' -f1)"

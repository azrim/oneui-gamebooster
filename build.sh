#!/usr/bin/env bash
# Samsung Game Booster - KernelSU/Magisk module builder.
#
# Fetches the Samsung gaming apps from the Galaxy Store (plus GOS from APKPure),
# generates the additive permission allowlists and packs the module zip.
#
# Env overrides: VERSION, VERSIONCODE, WORK, DIST, GS_DEVICES, GOS_URL
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
GOS_URL="${GOS_URL:-https://d.apkpure.com/b/APK/com.samsung.android.game.gos?version=latest}"

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

for c in curl python3 zip; do command -v "$c" >/dev/null || die "$c not found"; done

rm -rf "$WORK"
mkdir -p "$WORK/apks" "$DIST"

log "Fetching Game Booster (modern, API 35+)  [$(gs_version_name com.samsung.android.game.gametools $GT_MODERN_SDK $GT_MODERN_UI 2>/dev/null || echo '?')]"
fetch_apk com.samsung.android.game.gametools "$GT_MODERN_SDK" "$GT_MODERN_UI" "$WORK/apks/gametools-modern.apk" \
    || die "could not fetch modern gametools"

log "Fetching Game Booster (legacy, API 30-34) [$(gs_version_name com.samsung.android.game.gametools $GT_LEGACY_SDK $GT_LEGACY_UI 2>/dev/null || echo '?')]"
fetch_apk com.samsung.android.game.gametools "$GT_LEGACY_SDK" "$GT_LEGACY_UI" "$WORK/apks/gametools-legacy.apk" \
    || die "could not fetch legacy gametools"

log "Fetching Game Launcher"
fetch_apk com.samsung.android.game.gamehome "$GAMEHOME_SDK" "$GAMEHOME_UI" "$WORK/apks/gamehome.apk" \
    || die "could not fetch gamehome"

# GOS is not distributed on the Galaxy Store, so it comes from a mirror. Some mirrors
# (e.g. APKPure) block datacenter IPs, so this step is best-effort: the module still
# builds and works without GOS, it just loses the background optimisation service.
log "Fetching GOS"
GOS_APK=""
for url in "$GOS_URL" \
           "https://d.apkpure.com/b/APK/com.samsung.android.game.gos?version=latest" \
           "https://d.apkpure.com/b/XAPK/com.samsung.android.game.gos?version=latest"; do
    if curl -fL --retry 2 --max-time 600 -A "Mozilla/5.0 (Linux; Android 14)" \
            -o "$WORK/apks/gos.apk" "$url"; then
        GOS_APK="$WORK/apks/gos.apk"
        break
    fi
done
if [ -n "$GOS_APK" ]; then
    log "  GOS $(python3 "$REPO_DIR/scripts/axml.py" "$GOS_APK" 2>/dev/null | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' | head -1)"
else
    printf '\033[1;33m!!\033[0m GOS could not be fetched (mirror blocked?) - building without it\n'
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
if [ -n "$GOS_APK" ]; then
    cp "$GOS_APK" "$MOD/system/priv-app/GameOptimizationService/GameOptimizationService.apk"
fi

log "Generating permission allowlists"
PRIVAPP_APKS=("$WORK/apks/gametools-modern.apk" "$WORK/apks/gametools-legacy.apk")
if [ -n "$GOS_APK" ]; then
    PRIVAPP_APKS+=("$GOS_APK")
fi
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

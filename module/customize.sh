#!/system/bin/sh
# Samsung Game Booster - one module for all ROMs.
# Auto-selects the Game Booster (gametools) APK that matches the ROM's Android version.

ui_print "**********************************************"
ui_print "  Samsung Game Booster restore"
ui_print "**********************************************"

SDK="$(getprop ro.build.version.sdk)"
[ -n "$SDK" ] || SDK=0
ui_print "- ROM Android SDK: $SDK"

GT_DIR="$MODPATH/system/priv-app/GameTools_Dream"
mkdir -p "$GT_DIR"

if [ "$SDK" -ge 35 ]; then
  ui_print "- Game Booster: modern build (API 35+)"
elif [ "$SDK" -ge 30 ]; then
  ui_print "- Game Booster: legacy build (API 30-34)"
  cp -f "$MODPATH/apks/gametools-legacy.apk" "$GT_DIR/GameTools_Dream.apk"
else
  ui_print "! WARNING: ROM is API $SDK - Game Booster needs API 30+. It may not install."
  cp -f "$MODPATH/apks/gametools-legacy.apk" "$GT_DIR/GameTools_Dream.apk"
fi
chmod 0644 "$GT_DIR/GameTools_Dream.apk"

ui_print "- GOS + Game Launcher included"
ui_print "- Permission allowlists added additively (ROM's own kept)"

rm -rf "$MODPATH/apks"
ui_print "- Reboot to apply"

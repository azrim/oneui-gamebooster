#!/system/bin/sh
# Samsung Game Booster - one module for all ROMs.
# Auto-selects the Game Booster (gametools) and GOS APKs that match the ROM's Android version.

ui_print "**********************************************"
ui_print "  Samsung Game Booster restore"
ui_print "**********************************************"

SDK="$(getprop ro.build.version.sdk)"
[ -n "$SDK" ] || SDK=0
ui_print "- ROM Android SDK: $SDK"

GT_DIR="$MODPATH/system/priv-app/GameTools_Dream"
GOS_DIR="$MODPATH/system/priv-app/GameOptimizationService"
mkdir -p "$GT_DIR" "$GOS_DIR"

# --- Game Booster (gametools): modern ships in system/, legacy in apks/ ---
if [ "$SDK" -ge 35 ]; then
  ui_print "- Game Booster: modern build (API 35+)"
else
  if [ "$SDK" -ge 30 ]; then
    ui_print "- Game Booster: legacy build (API 30-34)"
  else
    ui_print "! WARNING: ROM is API $SDK - Game Booster needs API 30+"
  fi
  if [ -f "$MODPATH/apks/gametools-legacy.apk" ]; then
    cp -f "$MODPATH/apks/gametools-legacy.apk" "$GT_DIR/GameTools_Dream.apk"
  fi
fi
if [ -f "$GT_DIR/GameTools_Dream.apk" ]; then
  chmod 0644 "$GT_DIR/GameTools_Dream.apk"
fi

# --- Game Optimization Service: modern (API 33+) ships in system/, legacy in apks/ ---
if [ "$SDK" -ge 33 ]; then
  ui_print "- GOS: modern build (API 33+)"
elif [ "$SDK" -ge 29 ]; then
  ui_print "- GOS: legacy build (API 29-32)"
  if [ -f "$MODPATH/apks/gos-legacy.apk" ]; then
    cp -f "$MODPATH/apks/gos-legacy.apk" "$GOS_DIR/GameOptimizationService.apk"
  fi
else
  ui_print "! WARNING: ROM is API $SDK - GOS needs API 29+, skipping it"
  rm -f "$GOS_DIR/GameOptimizationService.apk"
fi
if [ -f "$GOS_DIR/GameOptimizationService.apk" ]; then
  chmod 0644 "$GOS_DIR/GameOptimizationService.apk"
fi

ui_print "- Game Launcher included"
ui_print "- Permission allowlists added additively (ROM's own kept)"

rm -rf "$MODPATH/apks"
ui_print "- Reboot to apply"

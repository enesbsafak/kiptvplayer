#!/usr/bin/env bash
# Installs the APK on the running emulator, opens the app and checks it
# stays up: no Java crash, no Rust panic, the process alive after 20 s.
# Leaves a screenshot and the log in $OUT (default: android-smoke/).
#
#   tools/android-smoke.sh path/to/app.apk
#
# TV=1 (an Android TV emulator): the app must be on the TV launcher, and a
# few remote presses (down, OK, back) must not bring it down.
set -u
APK=$1
OUT=${OUT:-android-smoke}
PKG=dev.karadelik.player
mkdir -p "$OUT"

adb wait-for-device
adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity"
sleep 20

adb exec-out screencap -p > "$OUT/start.png"

status=0
if [ "${TV:-}" = 1 ]; then
  if ! adb shell cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER | grep -q "$PKG"; then
    echo "::error::the app is not on the TV launcher (LEANBACK_LAUNCHER)"
    status=1
  fi
  for key in DPAD_DOWN DPAD_DOWN DPAD_RIGHT DPAD_CENTER; do
    adb shell input keyevent "KEYCODE_$key"
    sleep 1
  done
  adb exec-out screencap -p > "$OUT/remote.png"
  adb shell input keyevent KEYCODE_BACK
  sleep 2
fi
adb logcat -d > "$OUT/logcat.txt"
if ! adb shell pidof "$PKG" > /dev/null; then
  echo "::error::the app is not running 20 s after start"
  status=1
fi
if grep -E "FATAL EXCEPTION|panicked at|Fatal signal" "$OUT/logcat.txt"; then
  echo "::error::crash in the log (see the logcat artifact)"
  status=1
fi
grep -E "flutter|karadelik" "$OUT/logcat.txt" | tail -40
exit $status

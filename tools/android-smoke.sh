#!/usr/bin/env bash
# Installs the APK on the running emulator, opens the app and checks it
# stays up: no Java crash, no Rust panic, the process alive after 20 s.
# Leaves a screenshot and the log in $OUT (default: android-smoke/).
#
#   tools/android-smoke.sh path/to/app.apk
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
adb logcat -d > "$OUT/logcat.txt"

status=0
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

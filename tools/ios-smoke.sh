#!/usr/bin/env bash
# Boots an iPhone simulator, installs the simulator build, opens the app and
# checks it stays up for 20 s. Leaves a screenshot and the log in $OUT.
#
#   tools/ios-smoke.sh apps/player/build/ios/iphonesimulator/Runner.app
set -u
APP=$1
OUT=${OUT:-ios-smoke}
BUNDLE=dev.karadelik.player
mkdir -p "$OUT"

DEVICE=$(xcrun simctl list devices available -j |
  python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for r,l in sorted(d.items(), reverse=True) if 'iOS' in r for x in l if x['name'].startswith('iPhone')))")
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch --console-pty "$DEVICE" "$BUNDLE" > "$OUT/console.txt" 2>&1 &
sleep 20

xcrun simctl io "$DEVICE" screenshot "$OUT/start.png"
status=0
if ! xcrun simctl spawn "$DEVICE" launchctl list | grep -q "$BUNDLE"; then
  echo "::error::the app is not running 20 s after start"
  status=1
fi
if grep -E "panicked at|Fatal error|Terminating app" "$OUT/console.txt"; then
  echo "::error::crash in the console log"
  status=1
fi
tail -40 "$OUT/console.txt"
exit $status

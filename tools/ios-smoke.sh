#!/usr/bin/env bash
# Boots an iPhone simulator, installs the simulator build, opens the app and
# checks it stays up for 20 s. Leaves a screenshot and the log in $OUT.
#
#   tools/ios-smoke.sh apps/player/build/ios/iphonesimulator/Runner.app
#
# The hosted runners' simulators sometimes come up without their home screen
# (bootstatus ends with status -1) and then ignore the first launch: booting
# and launching are retried, a crash of the app itself is not.
set -u
APP=$1
OUT=${OUT:-ios-smoke}
BUNDLE=dev.karadelik.player
mkdir -p "$OUT"

DEVICE=$(xcrun simctl list devices available -j |
  python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for r,l in sorted(d.items(), reverse=True) if 'iOS' in r for x in l if x['name'].startswith('iPhone')))")

running() { xcrun simctl spawn "$DEVICE" launchctl list | grep -q "$BUNDLE"; }

for attempt in 1 2 3; do
  xcrun simctl boot "$DEVICE" 2> /dev/null
  if xcrun simctl bootstatus "$DEVICE" -b | tee "$OUT/boot-$attempt.txt" | grep -q "Status=4294967295"; then
    echo "simulator boot did not finish (attempt $attempt); restarting it"
    xcrun simctl shutdown "$DEVICE"
    continue
  fi
  break
done
xcrun simctl install "$DEVICE" "$APP"

for attempt in 1 2 3; do
  xcrun simctl launch --console-pty "$DEVICE" "$BUNDLE" > "$OUT/console.txt" 2>&1 &
  launcher=$!
  sleep 20
  if running || grep -qE "panicked at|Fatal error|Terminating app" "$OUT/console.txt"; then
    break
  fi
  # Not started at all (an empty console): the simulator lost the launch.
  if [ -s "$OUT/console.txt" ]; then break; fi
  echo "the launch did not start the app (attempt $attempt); trying again"
  kill "$launcher" 2> /dev/null
done

xcrun simctl io "$DEVICE" screenshot "$OUT/start.png"
status=0
if ! running; then
  echo "::error::the app is not running 20 s after start"
  status=1
fi
if grep -E "panicked at|Fatal error|Terminating app" "$OUT/console.txt"; then
  echo "::error::crash in the console log"
  status=1
fi
tail -40 "$OUT/console.txt"
exit $status

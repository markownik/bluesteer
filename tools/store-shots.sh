#!/bin/bash
# Store screenshots from the remote app in demo mode (a scripted Mac, no real host needed).
#
#   tools/store-shots.sh [ios|android|all]        default: all
#
# iOS: boots the "iPhone 15 Plus" simulator (6.7", 1290×2796, the App Store's required
# size), sets the status bar to 9:41 / full bars, runs the integration test that walks
# the screens and saves them. Android: uses the attached phone or a running emulator,
# switches the system UI to demo mode (clean status bar), runs the same test, then crops
# the captures to 2:1 for the Play listing. Results go to docs/store/screenshots/ and
# tools/store-kit.py is re-run so ~/Desktop/BlueSteer-store matches.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/apps/remote"
OUT="$ROOT/docs/store/screenshots"
SIM_NAME="${SIM_NAME:-iPhone 15 Plus}"
WHAT="${1:-all}"

PORT="${STORE_SHOTS_PORT:-8765}"

drive() { # drive <ios|android> <device id>: the test asks shot-server.py for a native capture of each screen
  rm -rf "$APP/build/screenshots/$1"
  python3 -I "$ROOT/tools/shot-server.py" "$PORT" "$1" "$2" "$APP/build/screenshots" &
  local server=$! rc=0
  (cd "$APP" && flutter drive --dart-define=BLUESTEER_DEMO=true --dart-define=STORE_SHOTS_PORT="$PORT" \
      --driver=test_driver/integration_test.dart --target=integration_test/screenshots_test.dart -d "$2") || rc=$?
  kill "$server" 2>/dev/null; wait "$server" 2>/dev/null || true
  return $rc
}

ios() {
  local udid
  udid=$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for r in d.values() for x in r if x['name']=='$SIM_NAME'))")
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName ""
  drive ios "$udid"
  xcrun simctl status_bar "$udid" clear
  rm -rf "$OUT/ios" && mkdir -p "$OUT/ios"
  cp "$APP"/build/screenshots/ios/*.png "$OUT/ios/"
  echo "iOS: $(ls "$OUT/ios" | wc -l | tr -d ' ') screenshots in $OUT/ios ($(sips -g pixelWidth -g pixelHeight "$OUT/ios/01-hosts.png" | awk '/pixel/ {printf "%s ", $2}'))"
}

android() {
  local serial
  serial=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')
  [ -n "$serial" ] || { echo "no Android device or emulator attached" >&2; exit 1; }
  adb -s "$serial" shell settings put global sysui_demo_allowed 1
  adb -s "$serial" shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
  adb -s "$serial" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
  adb -s "$serial" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
  adb -s "$serial" shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e mobile show -e datatype none -e level 4 >/dev/null
  adb -s "$serial" shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
  adb -s "$serial" reverse "tcp:$PORT" "tcp:$PORT"
  drive android "$serial" || { adb -s "$serial" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null; exit 1; }
  adb -s "$serial" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
  rm -rf "$OUT/android" && mkdir -p "$OUT/android/play"
  cp "$APP"/build/screenshots/android/*.png "$OUT/android/"
  # Play wants the long side at most twice the short one: drop the status bar (Samsung's One UI
  # ignores the demo-mode clock) and keep the next 2:1 of each capture.
  local bar; bar=$(adb -s "$serial" shell dumpsys window | grep -m1 -o 'type=statusBars frame=\[0,0\]\[[0-9]*,[0-9]*\]' | grep -o '[0-9]*\]$' | tr -d ']')
  crop_android "${bar:-0}"
  echo "Android: $(ls "$OUT/android"/*.png | wc -l | tr -d ' ') screenshots in $OUT/android (Play crops in android/play)"
}

crop_android() { # crop_android <status bar height px>
  python3 -I -c '
import sys, pathlib
from PIL import Image
top = int(sys.argv[2])
for f in sys.argv[3:]:
    im = Image.open(f); w = im.width
    im.crop((0, top, w, min(im.height, top + 2 * w))).save(pathlib.Path(sys.argv[1]) / pathlib.Path(f).name)
' "$OUT/android/play" "$1" "$OUT"/android/*.png
}

case "$WHAT" in
  ios) ios ;;
  android) android ;;
  all) ios; android ;;
  *) echo "usage: $0 [ios|android|all]" >&2; exit 64 ;;
esac
python3 -I "$ROOT/tools/store-kit.py"

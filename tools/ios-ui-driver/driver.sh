#!/bin/sh
# Drive the BlueSteer remote on a USB-connected iPhone through the UIDriver
# XCUITest bundle (UIDriverUITests.swift). Needs Xcode and libimobiledevice's
# iproxy (brew install libimobiledevice).
#
#   UDID=00008120-... driver.sh build         # once (and after editing the test)
#   driver.sh start                           # runs the test + iproxy in the background
#   driver.sh tree | tap <label> | tapxy <x> <y> | press <label> | type <text>
#   driver.sh swipe <x> <y> <x2> <y2> | home
#   driver.sh shot out.png | info | activate | stop
set -e
here=$(cd "$(dirname "$0")" && pwd)
udid=${UDID:?set UDID to the iPhone device identifier}
port=8099
url="http://127.0.0.1:$port"

encode() { printf '%s' "$1" | xxd -p | tr -d '\n' | sed 's/../%&/g'; }

case "$1" in
  build)
    xcodebuild build-for-testing -project "$here/UIDriver.xcodeproj" -scheme UIDriverUITests \
      -destination "id=$udid" -derivedDataPath "$here/build" SYMROOT="$here/build/Products" -allowProvisioningUpdates -quiet ;;
  start)
    xctestrun=$(ls "$here"/build/Products/UIDriverUITests_*.xctestrun | head -1)
    nohup xcodebuild test-without-building -xctestrun "$xctestrun" -destination "id=$udid" \
      -resultBundlePath "$here/build/run-$(date +%s).xcresult" > "$here/build/driver.log" 2>&1 &
    echo $! > "$here/build/xcodebuild.pid"
    nohup iproxy "$port" "$port" -u "$udid" > "$here/build/iproxy.log" 2>&1 &
    echo $! > "$here/build/iproxy.pid"
    echo "started; wait for '$0 info' to answer" ;;
  stop)
    curl -s "$url/quit" || true
    for p in xcodebuild iproxy; do [ -f "$here/build/$p.pid" ] && kill "$(cat "$here/build/$p.pid")" 2>/dev/null; done
    echo stopped ;;
  tree|info|activate|terminate|home) curl -s "$url/$1" ;;
  swipe) curl -s "$url/swipe?x=$2&y=$3&x2=$4&y2=$5" ;;
  tap|press) curl -s "$url/$1?label=$(encode "$2")" ;;
  tapxy) curl -s "$url/tap?x=$2&y=$3" ;;
  type) curl -s "$url/type?text=$(encode "$2")" ;;
  shot) curl -s "$url/screenshot" -o "${2:-shot.png}" && echo "saved ${2:-shot.png}" ;;
  *) echo "unknown command $1" >&2; exit 2 ;;
esac

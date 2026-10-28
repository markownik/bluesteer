#!/usr/bin/env bash
# Builds BlueSteerHost in release and wraps it into BlueSteer.app so macOS
# honours the Bluetooth usage description and menu-bar-only setting.
#   tools/bundle-app.sh [--sign "Developer ID Application: ..."]
set -euo pipefail
cd "$(dirname "$0")/../apps/host"

IDENTITY="-"   # ad-hoc by default
if [[ "${1:-}" == "--sign" ]]; then IDENTITY="$2"; fi

swift build -c release --product BlueSteerHost
BIN=$(swift build -c release --product BlueSteerHost --show-bin-path)/BlueSteerHost
APP=../../build/BlueSteer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/BlueSteerHost"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>BlueSteer</string>
  <key>CFBundleDisplayName</key><string>BlueSteer</string>
  <key>CFBundleIdentifier</key><string>dev.bluesteer.host</string>
  <key>CFBundleExecutable</key><string>BlueSteerHost</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>BlueSteer uses Bluetooth to let your paired devices attach to terminal sessions on this Mac.</string>
</dict></plist>
PLIST
codesign --force --sign "$IDENTITY" "$APP"
echo "built $APP"

#!/usr/bin/env bash
# Builds BlueSteerHost in release and wraps it into BlueSteer.app so macOS
# honours the Bluetooth usage description and menu-bar-only setting.
#   tools/bundle-app.sh [--sign "Developer ID Application: ..."]
set -euo pipefail
cd "$(dirname "$0")/../apps/host"

IDENTITY="-"   # ad-hoc by default
if [[ "${1:-}" == "--sign" ]]; then IDENTITY="$2"; fi
# Notarization needs a secure timestamp; an ad-hoc signature cannot carry one.
TIMESTAMP=--timestamp=none
if [[ "$IDENTITY" != "-" ]]; then TIMESTAMP=--timestamp; fi

swift build -c release --product BlueSteerHost
swift build -c release --product bluesteer
BINDIR=$(swift build -c release --product BlueSteerHost --show-bin-path)
APP=../../build/BlueSteer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINDIR/BlueSteerHost" "$APP/Contents/MacOS/BlueSteerHost"
# The command line tool ships next to the app binary; the host symlinks it for the hooks.
cp "$BINDIR/bluesteer" "$APP/Contents/MacOS/bluesteer"
# Menu-bar icon PNGs straight into Resources (the SwiftPM resource bundle's accessor
# cannot find a bundle inside an .app; the app reads them from Bundle.main) and the app icon.
cp "$BINDIR"/BlueSteerHostApp_BlueSteerHost.bundle/MenuBarIcon*.png "$APP/Contents/Resources/"
cp ../../assets/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>BlueSteer</string>
  <key>CFBundleDisplayName</key><string>BlueSteer</string>
  <key>CFBundleIdentifier</key><string>app.devland.bluesteer.host.macos</string>
  <key>CFBundleExecutable</key><string>BlueSteerHost</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>BlueSteer uses Bluetooth to let your paired devices attach to terminal sessions on this Mac.</string>
</dict></plist>
PLIST
# Hardened runtime on both executables (notarization requires it); the tool is
# signed first because it is nested inside the bundle. Entitlements: Bluetooth
# (for a future sandbox) and the exceptions the PTY helpers need.
ENTITLEMENTS=$(mktemp -t bluesteer-entitlements).plist
cat > "$ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.device.bluetooth</key><true/>
</dict></plist>
PLIST
codesign --force --options runtime "$TIMESTAMP" --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP/Contents/MacOS/bluesteer"
codesign --force --options runtime "$TIMESTAMP" --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
rm -f "$ENTITLEMENTS"
codesign --verify --strict --deep "$APP"
echo "built $APP (signed: $IDENTITY)"

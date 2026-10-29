#!/usr/bin/env bash
# Packs build/BlueSteer.app into build/BlueSteer-<version>.dmg and, when a
# notarytool keychain profile is given, notarizes and staples it.
#   tools/make-dmg.sh [--sign "Developer ID Application: ..."] [--notarize <keychain-profile>]
# The DMG is only distributable when signed with a Developer ID identity
# (`security find-identity -v -p codesigning`) and notarized; an ad-hoc build
# is for local testing. Create the profile once with
#   xcrun notarytool store-credentials <profile> --apple-id <id> --team-id <team> --password <app-specific password>
set -euo pipefail
cd "$(dirname "$0")/.."
IDENTITY="-"; PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sign) IDENTITY=$2; shift 2 ;;
    --notarize) PROFILE=$2; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 64 ;;
  esac
done
tools/bundle-app.sh --sign "$IDENTITY"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' build/BlueSteer.app/Contents/Info.plist)
DMG=build/BlueSteer-$VERSION.dmg
STAGE=$(mktemp -d -t bluesteer-dmg)
cp -R build/BlueSteer.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "BlueSteer" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
codesign --force --sign "$IDENTITY" "$DMG"
if [ -n "$PROFILE" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
fi
echo "built $DMG"

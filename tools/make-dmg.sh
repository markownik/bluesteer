#!/usr/bin/env bash
# Packs build/BlueSteer.app into build/BlueSteer-<version>.dmg and, when a
# notarytool keychain profile is given, notarizes and staples both.
#   tools/make-dmg.sh [--sign "Developer ID Application: ..."] [--notarize <keychain-profile>]
# The DMG is only distributable when signed with a Developer ID identity
# (`security find-identity -v -p codesigning`) and notarized; an ad-hoc build
# is for local testing. Create the profile once with
#   xcrun notarytool store-credentials <profile> --apple-id <id> --team-id <team> --password <app-specific password>
# The app is notarized and stapled first, so the copy inside the DMG carries
# its own ticket (Gatekeeper then needs no network on the installing Mac);
# the DMG is notarized and stapled after that.
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
TIMESTAMP=""
if [ "$IDENTITY" != "-" ]; then TIMESTAMP="--timestamp"; fi
tools/bundle-app.sh --sign "$IDENTITY"
APP=build/BlueSteer.app
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
if [ -n "$PROFILE" ]; then
  ZIP=build/BlueSteer-$VERSION.zip
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
fi
DMG=build/BlueSteer-$VERSION.dmg
STAGE=$(mktemp -d -t bluesteer-dmg)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "BlueSteer" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
# shellcheck disable=SC2086  # $TIMESTAMP is empty or one flag
codesign --force $TIMESTAMP --sign "$IDENTITY" "$DMG"
if [ -n "$PROFILE" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl -a -t exec -vv "$APP"
  spctl -a -t open --context context:primary-signature -vv "$DMG"
fi
echo "built $DMG"

#!/usr/bin/env bash
# Builds, notarizes, tags and publishes a BlueSteer Host release.
#   tools/release.sh <version> [--skip-build] [--skip-tag]
# Steps:
#   1. checks that <version> is what HostInfo.version, tools/bundle-app.sh and
#      apps/remote/pubspec.yaml say and that the working tree is clean;
#   2. tools/make-dmg.sh --sign "$SIGN_IDENTITY" --notarize "$NOTARY_PROFILE"
#      → build/BlueSteer-<version>.dmg, notarized and stapled;
#   3. writes build/BlueSteer-<version>.dmg.sha256, the notarization log
#      (build/BlueSteer-<version>-notarization.json) and the release notes
#      (build/release-notes-<version>.md);
#   4. tags v<version> (annotated) and pushes the tag to origin and, when it
#      exists, to the `github` remote (the public mirror);
#   5. creates the GitHub Release with the DMG attached: through `gh` when it is
#      installed and logged in, otherwise through the REST API with GITHUB_TOKEN
#      from the environment (a token with `contents: write` on the mirror).
#      Without either it prints what to upload by hand.
# Keep build/BlueSteer-<version>.dmg, its .sha256 and the notarization log with
# the tag (docs/store/beta-checklist.md §1).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: tools/release.sh <version> [--skip-build] [--skip-tag]}; shift
SKIP_BUILD=0; SKIP_TAG=0
for a in "$@"; do
  case "$a" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-tag) SKIP_TAG=1 ;;
    *) echo "unknown option $a" >&2; exit 64 ;;
  esac
done
SIGN_IDENTITY=${SIGN_IDENTITY:-"Developer ID Application: Marek Biedrzycki (SCEKMP2WZT)"}
NOTARY_PROFILE=${NOTARY_PROFILE:-bluesteer}
GITHUB_REPO=${GITHUB_REPO:-markownik/bluesteer}
TAG="v$VERSION"
DMG="build/BlueSteer-$VERSION.dmg"
NOTES="build/release-notes-$VERSION.md"

# 1. version consistency and a clean tree
for f in apps/host/Sources/HostCore/HostCore.swift tools/bundle-app.sh apps/remote/pubspec.yaml; do
  grep -q "\"$VERSION\"\|<string>$VERSION</string>\|^version: $VERSION+" "$f" || { echo "$f does not say $VERSION" >&2; exit 1; }
done
if [ -n "$(git status --porcelain)" ]; then echo "working tree not clean; commit the version bump first" >&2; exit 1; fi

# 2. notarized DMG
if [ "$SKIP_BUILD" = 0 ]; then
  tools/make-dmg.sh --sign "$SIGN_IDENTITY" --notarize "$NOTARY_PROFILE"
fi
[ -f "$DMG" ] || { echo "$DMG missing" >&2; exit 1; }

# 3. hash, notarization log, release notes
(cd build && shasum -a 256 "BlueSteer-$VERSION.dmg" > "BlueSteer-$VERSION.dmg.sha256")
SHA=$(cut -d' ' -f1 "$DMG.sha256")
SUBMISSION=$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["history"][0]["id"])')
xcrun notarytool log "$SUBMISSION" --keychain-profile "$NOTARY_PROFILE" "build/BlueSteer-$VERSION-notarization.json" >/dev/null
cat > "$NOTES" <<EOF
BlueSteer Host $VERSION for macOS 14 or newer, signed with a Developer ID and notarized by Apple.

Install: open the DMG, drag BlueSteer to Applications and open it. Pair the free BlueSteer Remote on your iPhone or Android phone: https://bluesteer.devland.app/support

SHA-256 of \`BlueSteer-$VERSION.dmg\`:

    $SHA

Check it with \`shasum -a 256 BlueSteer-$VERSION.dmg\`. BlueSteer is free; if it is useful to you: https://github.com/sponsors/markownik
EOF
echo "notes: $NOTES"; cat "$DMG.sha256"

# 4. tag and push
if [ "$SKIP_TAG" = 0 ]; then
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "tag $TAG exists, keeping it"
  else
    git tag -a "$TAG" -m "BlueSteer $VERSION"
  fi
  git push origin "$TAG"
  if git remote | grep -qx github; then git push github main "$TAG"; fi
fi

# 5. GitHub Release on the mirror
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh release create "$TAG" "$DMG" "$DMG.sha256" --repo "$GITHUB_REPO" --title "BlueSteer $VERSION" --notes-file "$NOTES"
elif [ -n "${GITHUB_TOKEN:-}" ]; then
  API="https://api.github.com/repos/$GITHUB_REPO/releases"
  BODY=$(python3 -c 'import json,sys; print(json.dumps({"tag_name": sys.argv[1], "name": "BlueSteer " + sys.argv[2], "body": open(sys.argv[3]).read()}))' "$TAG" "$VERSION" "$NOTES")
  UPLOAD=$(curl -fsS -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$API" -d "$BODY" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["upload_url"].split("{")[0])')
  for f in "$DMG" "$DMG.sha256"; do
    curl -fsS -o /dev/null -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/octet-stream" \
      "$UPLOAD?name=$(basename "$f")" --data-binary @"$f"
  done
  echo "release https://github.com/$GITHUB_REPO/releases/tag/$TAG"
else
  echo "No gh login and no GITHUB_TOKEN: create the release by hand at https://github.com/$GITHUB_REPO/releases/new?tag=$TAG"
  echo "  title 'BlueSteer $VERSION', notes from $NOTES, attach $DMG and $DMG.sha256"
fi

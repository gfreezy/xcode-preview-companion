#!/usr/bin/env bash
#
# Build, sign, and package XcodePreviewCompanion into a DMG.
#
# Environment overrides:
#   CONFIG          Build configuration (default: Release)
#   DERIVED_DATA    xcodebuild derived data dir (default: build)
#   DIST            Output directory for the DMG (default: dist)
#   SIGN_IDENTITY   codesign identity (default: "-", ad-hoc)
#                   In CI this is the self-signed certificate's common name.
#   VERSION         Marketing version used in the DMG file name
#                   (default: read from the built app's Info.plist)
#   SKIP_BUILD      If set, reuse an existing build instead of rebuilding
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="XcodePreviewCompanion"
PROJECT="$SCHEME.xcodeproj"
CONFIG="${CONFIG:-Release}"
DERIVED_DATA="${DERIVED_DATA:-build}"
DIST="${DIST:-dist}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="$DERIVED_DATA/Build/Products/$CONFIG/$SCHEME.app"

log() { printf '\033[36m==>\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Generate the Xcode project and build a Release .app
# ---------------------------------------------------------------------------
if [ -z "${SKIP_BUILD:-}" ]; then
  log "Generating Xcode project (xcodegen)"
  xcodegen generate

  log "Building $SCHEME ($CONFIG)"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

[ -d "$APP" ] || { echo "error: app not found at $APP" >&2; exit 1; }

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 0.0.0)}"

# ---------------------------------------------------------------------------
# 2. Sign the .app
# ---------------------------------------------------------------------------
# Ad-hoc ("-") signatures cannot carry a secure timestamp or hardened runtime
# reliably; a real/self-signed identity can and should.
SIGN_FLAGS=(--force --deep --sign "$SIGN_IDENTITY")
if [ "$SIGN_IDENTITY" != "-" ]; then
  SIGN_FLAGS+=(--options runtime --timestamp)
fi

log "Signing app with identity: $SIGN_IDENTITY"
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# ---------------------------------------------------------------------------
# 3. Build the DMG
# ---------------------------------------------------------------------------
DMG="$DIST/$SCHEME-$VERSION.dmg"
mkdir -p "$DIST"
rm -f "$DMG"

# create-dmg copies the entire source folder into the image, so stage just the app.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"

log "Creating DMG: $DMG"
create-dmg \
  --volname "$SCHEME" \
  --window-pos 200 120 \
  --window-size 560 380 \
  --icon-size 110 \
  --icon "$SCHEME.app" 150 190 \
  --hide-extension "$SCHEME.app" \
  --app-drop-link 410 190 \
  --no-internet-enable \
  "$DMG" \
  "$STAGE" \
  || true   # create-dmg returns non-zero when it can't set a custom volume icon (headless CI); the DMG is still produced.

[ -f "$DMG" ] || { echo "error: DMG was not created at $DMG" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 4. Sign the DMG itself (skipped for ad-hoc)
# ---------------------------------------------------------------------------
if [ "$SIGN_IDENTITY" != "-" ]; then
  log "Signing DMG with identity: $SIGN_IDENTITY"
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
  codesign --verify --verbose=2 "$DMG"
fi

log "Done: $DMG"
echo "$DMG"

#!/bin/bash
# Build an ad-hoc signed PlayCover.app and zip it for a GitHub release.
#
# Usage: scripts/build-adhoc.sh [release-label]
#   release-label  Name used in the zip file, for example 3.1.0-playchain.2.
#                  Defaults to the app's CFBundleShortVersionString.
#
# Ad-hoc code has no Team ID. With the hardened runtime on, library
# validation refuses the ad-hoc Sparkle framework and the app crashes at
# launch. This script turns the hardened runtime off and does not inject
# com.apple.security.get-task-allow.
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED_DATA="build/adhoc"
OUTPUT="output"
APP="$DERIVED_DATA/Build/Products/Release/PlayCover.app"

xcodebuild \
    -project PlayCover.xcodeproj \
    -scheme PlayCover \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM= \
    PROVISIONING_PROFILE_SPECIFIER= \
    ENABLE_HARDENED_RUNTIME=NO \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    clean build

echo "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

MAIN_INFO="$(codesign --display --verbose=2 "$APP" 2>&1)"
if ! grep -q "Signature=adhoc" <<<"$MAIN_INFO"; then
    echo "error: $APP is not ad-hoc signed" >&2
    exit 1
fi
if grep -q "flags=.*runtime" <<<"$MAIN_INFO"; then
    echo "error: $APP has the hardened runtime flag and will crash at launch" >&2
    exit 1
fi
if codesign --display --entitlements - "$APP" 2>/dev/null | grep -q "get-task-allow"; then
    echo "error: $APP has the com.apple.security.get-task-allow entitlement" >&2
    exit 1
fi

LABEL="${1:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")}"
ZIP="$OUTPUT/PlayCover-$LABEL.zip"

mkdir -p "$OUTPUT"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "Built $ZIP"
shasum -a 256 "$ZIP"

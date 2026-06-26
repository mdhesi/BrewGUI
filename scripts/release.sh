#!/usr/bin/env bash
#
# Builds, signs, packages, and notarizes a distributable BrewGUI.dmg.
# See RELEASING.md for the one-time setup (Developer ID cert + notary profile).
#
# Usage:
#   ./scripts/release.sh                 # version read from the project
#   VERSION=1.0.0 ./scripts/release.sh   # or pin it explicitly
#
set -euo pipefail
cd "$(dirname "$0")/.."

# ---- Config (override via env) ------------------------------------------------
SCHEME="${SCHEME:-BrewGUI}"
PROJECT="${PROJECT:-BrewGUI.xcodeproj}"
CONFIGURATION="${CONFIGURATION:-Release}"
APP_NAME="BrewGUI"
BUILD_DIR="${BUILD_DIR:-build}"
# Keychain profile created once via `xcrun notarytool store-credentials`.
NOTARY_PROFILE="${NOTARY_PROFILE:-brewgui-notary}"

ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"

VERSION="${VERSION:-$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk '/ MARKETING_VERSION / {print $3; exit}')}"
VERSION="${VERSION:-1.0.0}"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "▶ Releasing $APP_NAME $VERSION"
rm -rf "$ARCHIVE" "$EXPORT_DIR" "$DMG"
mkdir -p "$BUILD_DIR"

# ---- 1. Archive ---------------------------------------------------------------
echo "▶ Archiving…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=macOS'

# ---- 2. Export with Developer ID ----------------------------------------------
echo "▶ Exporting (Developer ID)…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "scripts/ExportOptions.plist"

# ---- 3. Package as a DMG ------------------------------------------------------
echo "▶ Building DMG…"
STAGING="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

# ---- 4. Notarize + staple -----------------------------------------------------
echo "▶ Notarizing (a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo ""
echo "✔ Done: $DMG"
echo "  version: $VERSION"
echo "  sha256:  $(shasum -a 256 "$DMG" | awk '{print $1}')"
echo ""
echo "Next: upload to a GitHub Release tagged v$VERSION, then update the cask"
echo "      (version + sha256 + url) in your tap. See RELEASING.md."

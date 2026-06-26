#!/usr/bin/env bash
#
# Builds an unsigned Release BrewGUI.app and zips it for distribution via a
# GitHub Release. Needs NO Apple Developer account.
#
# Because it isn't notarized, users open it the first time via
# System Settings -> Privacy & Security -> "Open Anyway".
# For a notarized DMG instead, see release.sh + RELEASING.md.
#
# Usage:
#   ./scripts/package.sh                 # version read from the project
#   VERSION=1.0.0 ./scripts/package.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="${SCHEME:-BrewGUI}"
PROJECT="${PROJECT:-BrewGUI.xcodeproj}"
BUILD_DIR="${BUILD_DIR:-build}"
DD="$BUILD_DIR/dd"
APP_NAME="BrewGUI"

VERSION="${VERSION:-$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk '/ MARKETING_VERSION / {print $3; exit}')}"
VERSION="${VERSION:-1.0.0}"
ZIP="$BUILD_DIR/$APP_NAME-$VERSION.zip"

echo "▶ Building $APP_NAME $VERSION (Release, unsigned)…"
rm -rf "$DD" "$ZIP"
mkdir -p "$BUILD_DIR"

xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DD" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

APP="$DD/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "✗ build product not found at $APP"; exit 1; }

echo "▶ Zipping…"
ditto -c -k --keepParent "$APP" "$ZIP"

echo ""
echo "✔ Done: $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"
echo "  Upload it to a GitHub Release, e.g.:"
echo "    gh release create v$VERSION \"$ZIP\" --title \"BrewGUI $VERSION\" --notes \"…\""

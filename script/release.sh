#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/build-release"
OUTPUT_DIR="$PROJECT_DIR/release"
APP="$DERIVED_DATA/Build/Products/Release/万年历.app"
SPARKLE_TOOLS="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"

cd "$PROJECT_DIR"
xcodegen generate
xcodebuild \
  -project Calendar.xcodeproj \
  -scheme Calendar \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")
ARCHIVE_NAME="万年历-${VERSION}.zip"
DOWNLOAD_PREFIX="https://github.com/RaulVan/Wannianli/releases/download/v${VERSION}/"

mkdir -p "$OUTPUT_DIR"
find "$OUTPUT_DIR" -maxdepth 1 -type f \( -name '*.zip' -o -name '*.md' -o -name 'appcast.xml' \) -delete
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT_DIR/$ARCHIVE_NAME"

if [ -f "$PROJECT_DIR/appcast.xml" ]; then
  cp "$PROJECT_DIR/appcast.xml" "$OUTPUT_DIR/appcast.xml"
fi

"$SPARKLE_TOOLS/generate_appcast" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --link 'https://github.com/RaulVan/Wannianli' \
  --maximum-deltas 0 \
  "$OUTPUT_DIR"

cp "$OUTPUT_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Release ready: $OUTPUT_DIR/$ARCHIVE_NAME"
echo "Version: $VERSION ($BUILD)"
echo "Appcast: $PROJECT_DIR/appcast.xml"

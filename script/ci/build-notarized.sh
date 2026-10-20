#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${ASC_KEY_ID:?ASC_KEY_ID is required}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required}"
: "${ASC_PRIVATE_KEY_PATH:?ASC_PRIVATE_KEY_PATH is required}"

WORK="$PROJECT_DIR/build/ci"
OUTPUT="$PROJECT_DIR/release/ci"
mkdir -p "$WORK/logs" "$OUTPUT"
AUTH=(-authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
NOTARY_AUTH=(--key "$ASC_PRIVATE_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
xcodebuild -version
xcodegen generate
# Archive ad hoc; export performs automatic Developer ID signing of all nested code.
xcodebuild archive \
  -project Calendar.xcodeproj -scheme Calendar -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$WORK/Calendar.xcarchive" \
  -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  2>&1 | tee "$WORK/logs/archive.log"

python3 - "$WORK/ExportOptions.plist" <<'PY'
import os, pathlib, plistlib, sys
pathlib.Path(sys.argv[1]).write_bytes(plistlib.dumps({
    'method': 'developer-id', 'destination': 'export',
    'signingStyle': 'automatic', 'teamID': os.environ['APPLE_TEAM_ID'],
}))
PY
xcodebuild -exportArchive -archivePath "$WORK/Calendar.xcarchive" \
  -exportPath "$WORK/export" -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -allowProvisioningUpdates "${AUTH[@]}" 2>&1 | tee "$WORK/logs/export.log"

APP="$WORK/export/万年历.app"
WIDGET="$APP/Contents/PlugIns/WannianliWidget.appex"
test -d "$WIDGET"
test "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$WIDGET/Contents/Info.plist")" = 'com.apple.widgetkit-extension'
for bundle in "$APP" "$WIDGET"; do
  codesign --verify --deep --strict --verbose=2 "$bundle"
  DETAILS=$(codesign -dvv "$bundle" 2>&1)
  printf '%s\n' "$DETAILS" | grep -F 'Authority=Developer ID Application:' >/dev/null
  printf '%s\n' "$DETAILS" | grep -Fx "TeamIdentifier=$APPLE_TEAM_ID" >/dev/null
  printf '%s\n' "$DETAILS" | grep -F 'runtime' >/dev/null
  EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")
  lipo "$bundle/Contents/MacOS/$EXECUTABLE" -verify_arch arm64 x86_64
  codesign -d --entitlements :- "$bundle" 2>/dev/null | python3 -c 'import plistlib,sys; assert not plistlib.loads(sys.stdin.buffer.read()).get("com.apple.security.get-task-allow", False), "Debug entitlement in release"'
done

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$WORK/notarization.zip"
NOTARY_EXIT=0
xcrun notarytool submit "$WORK/notarization.zip" "${NOTARY_AUTH[@]}" \
  --wait --timeout 30m --output-format json > "$WORK/logs/notarization.json" || NOTARY_EXIT=$?
SUBMISSION_ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id", ""))' "$WORK/logs/notarization.json")
if [ -n "$SUBMISSION_ID" ]; then
  xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_AUTH[@]}" "$WORK/logs/notarization-log.json" || true
fi
if [ "$NOTARY_EXIT" -ne 0 ]; then exit "$NOTARY_EXIT"; fi
python3 - "$WORK/logs/notarization.json" "$WORK/logs/notarization-log.json" <<'PY'
import json, pathlib, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    log_path = pathlib.Path(sys.argv[2])
    log = json.loads(log_path.read_text()) if log_path.is_file() else {}
    if log.get('statusCode') == 7000:
        raise SystemExit('Apple notarization rejected (7000): team not configured; contact Apple Developer Program Support.')
    raise SystemExit('Apple notarization was not accepted; inspect notarization logs.')
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")
ZIP="Wannianli-${VERSION}-${BUILD}.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/$ZIP"
(cd "$OUTPUT" && shasum -a 256 "$ZIP" > SHA256SUMS)
python3 - "$OUTPUT/build-info.json" "$VERSION" "$BUILD" "$SUBMISSION_ID" <<'PY'
import json, os, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    'version': sys.argv[2], 'build': sys.argv[3], 'notarizationID': sys.argv[4],
    'notarizationStatus': 'Accepted', 'architectures': ['arm64', 'x86_64'],
    'commit': os.environ.get('GITHUB_SHA', ''), 'runID': os.environ.get('GITHUB_RUN_ID', ''),
}, indent=2) + '\n')
PY
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '### 万年历 %s (%s)\n\nDeveloper ID 签名、公证、票据装订及 Gatekeeper 检查通过。\n\n安装包见本次运行的 Artifact。\n' "$VERSION" "$BUILD" >> "$GITHUB_STEP_SUMMARY"
fi

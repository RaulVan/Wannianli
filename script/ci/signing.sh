#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
CREDENTIAL_DIR="$RUNNER_TEMP/wannianli-signing"
KEYCHAIN="$CREDENTIAL_DIR/signing.keychain-db"

case "${1:-}" in
  setup)
    for variable in APPLE_DEVELOPER_ID_P12_BASE64 APPLE_DEVELOPER_ID_PASSWORD APPLE_TEAM_ID ASC_PRIVATE_KEY ASC_KEY_ID ASC_ISSUER_ID GITHUB_ENV; do
      if [ -z "${!variable:-}" ]; then
        echo "Missing required setting: $variable" >&2
        exit 1
      fi
    done
    umask 077
    mkdir "$CREDENTIAL_DIR"
    security list-keychains -d user > "$CREDENTIAL_DIR/keychains-before.txt"
    printf '%s' "$APPLE_DEVELOPER_ID_P12_BASE64" | base64 --decode > "$CREDENTIAL_DIR/certificate.p12"
    printf '%s\n' "$ASC_PRIVATE_KEY" > "$CREDENTIAL_DIR/AuthKey.p8"
    openssl pkey -in "$CREDENTIAL_DIR/AuthKey.p8" -noout
    KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
    security set-keychain-settings -lut 21600 "$KEYCHAIN"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
    security import "$CREDENTIAL_DIR/certificate.p12" -k "$KEYCHAIN" \
      -P "$APPLE_DEVELOPER_ID_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
      -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
    python3 - "$CREDENTIAL_DIR/keychains-before.txt" "$KEYCHAIN" <<'PY'
import pathlib, shlex, subprocess, sys
paths = shlex.split(pathlib.Path(sys.argv[1]).read_text())
subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', sys.argv[2], *paths], check=True)
PY
    security find-identity -v -p codesigning "$KEYCHAIN" | \
      grep -F 'Developer ID Application:' | grep -F "($APPLE_TEAM_ID)" >/dev/null
    rm "$CREDENTIAL_DIR/certificate.p12"
    printf 'ASC_PRIVATE_KEY_PATH=%s\n' "$CREDENTIAL_DIR/AuthKey.p8" >> "$GITHUB_ENV"
    ;;
  cleanup)
    if [ -f "$CREDENTIAL_DIR/keychains-before.txt" ]; then
      python3 - "$CREDENTIAL_DIR/keychains-before.txt" <<'PY'
import pathlib, shlex, subprocess, sys
paths = shlex.split(pathlib.Path(sys.argv[1]).read_text())
subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', *paths], check=True)
PY
    fi
    if [ -f "$KEYCHAIN" ]; then
      security delete-keychain "$KEYCHAIN"
    fi
    rm -f "$CREDENTIAL_DIR/AuthKey.p8" "$CREDENTIAL_DIR/certificate.p12" "$CREDENTIAL_DIR/keychains-before.txt"
    if [ -d "$CREDENTIAL_DIR" ]; then rmdir "$CREDENTIAL_DIR"; fi
    ;;
  *) echo "Usage: $0 setup|cleanup" >&2; exit 2 ;;
esac

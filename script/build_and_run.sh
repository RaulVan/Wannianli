#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$PROJECT_DIR/build/Build/Products/Debug/万年历.app"
case "$MODE" in run|--verify|--logs|--telemetry|--debug) ;; *) echo "Usage: $0 [--verify|--logs|--telemetry|--debug]" >&2; exit 2 ;; esac
pkill -x 万年历 >/dev/null 2>&1 || true
# Clean up builds created before the product was renamed.
pkill -x Wannianli >/dev/null 2>&1 || true
cd "$PROJECT_DIR"
xcodebuild -project Calendar.xcodeproj -scheme Calendar -configuration Debug -destination 'platform=macOS' -derivedDataPath build build -quiet
if [ "$MODE" = "--debug" ]; then
  exec lldb "$APP/Contents/MacOS/万年历"
fi
/usr/bin/open -n "$APP"
case "$MODE" in
  --verify) sleep 2; pgrep -x 万年历 ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "万年历"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.Calendar.Wannianli"' ;;
esac

#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIND="${1:-main}"
OUTPUT="${2:?output file required}"
WINDOW_ID="$(swift "$PROJECT_DIR/script/window_id.swift" "$KIND")"
case "$WINDOW_ID" in ''|*[!0-9]*) exit 1 ;; esac
/usr/sbin/screencapture -x -o -l "$WINDOW_ID" "$OUTPUT"

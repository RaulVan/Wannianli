#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$PROJECT_DIR/Calendar/Resources/Icon/calendar-base.png"
STATIC="$PROJECT_DIR/Calendar/Resources/Icon/calendar-12-static.png"
APPICON_DIR="$PROJECT_DIR/Calendar/Assets.xcassets/AppIcon.appiconset"

command -v magick >/dev/null 2>&1 || {
  echo "ImageMagick (magick) is required to generate app icons." >&2
  exit 1
}

apply_transparent_silhouette() {
  local source="$1"
  local scale="$2"
  local output="$3"
  local mask
  mask="$(mktemp /tmp/calendar-icon-mask.XXXXXX.png)"

  magick -size "$((1254 * scale))x$((1254 * scale))" xc:black \
    -fill white \
    -draw "roundrectangle $((114 * scale)),$((122 * scale)) $((1140 * scale)),$((1118 * scale)) $((125 * scale)),$((125 * scale))" \
    -draw "roundrectangle $((310 * scale)),$((64 * scale)) $((387 * scale)),$((264 * scale)) $((38 * scale)),$((38 * scale))" \
    -draw "roundrectangle $((868 * scale)),$((64 * scale)) $((946 * scale)),$((264 * scale)) $((38 * scale)),$((38 * scale))" \
    "$mask"
  magick "$source" "$mask" -alpha off -compose CopyOpacity -composite "$output"
  rm -f "$mask"
}

base_temp="$(mktemp /tmp/calendar-base-transparent.XXXXXX.png)"
static_temp="$(mktemp /tmp/calendar-12-transparent.XXXXXX.png)"
trap 'rm -f "$base_temp" "$static_temp"' EXIT

apply_transparent_silhouette "$BASE" 1 "$base_temp"
apply_transparent_silhouette "$STATIC" 2 "$static_temp"
mv "$base_temp" "$BASE"
mv "$static_temp" "$STATIC"

for size in 16 32 64 128 256 512 1024; do
  magick "$STATIC" -filter Lanczos -resize "${size}x${size}" "$APPICON_DIR/icon-${size}.png"
done

echo "Generated transparent runtime and static app icons."

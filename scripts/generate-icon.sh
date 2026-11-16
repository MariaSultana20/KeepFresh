#!/usr/bin/env bash
#
# Rasterizes the KeepFresh icon SVG into a submission-compliant 1024×1024
# PNG (sRGB, no alpha channel) and installs it into the asset catalog.
#
# Requires ImageMagick with the rsvg delegate:  brew install imagemagick
#
# Usage:  ./scripts/generate-icon.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$PROJECT_DIR/docs/brand/keepfresh-icon.svg"
OUT="$PROJECT_DIR/KeepFresh/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

command -v rsvg-convert >/dev/null || { echo "error: rsvg-convert not found (brew install librsvg)" >&2; exit 1; }
command -v magick >/dev/null || { echo "error: ImageMagick not found (brew install imagemagick)" >&2; exit 1; }

TMP="$(mktemp -t keepfresh-icon).png"
trap 'rm -f "$TMP"' EXIT

echo "==> Rendering $SVG -> AppIcon-1024.png"
# rsvg-convert renders the SVG (gradients included) crisply; ImageMagick then
# flattens away the alpha channel and pins sRGB for App Store compliance.
rsvg-convert -w 1024 -h 1024 "$SVG" -o "$TMP"
magick "$TMP" -background white -flatten -alpha off -colorspace sRGB "$OUT"

echo "==> Result:"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$OUT" | sed 's/^/    /'

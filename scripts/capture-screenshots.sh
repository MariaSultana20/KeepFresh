#!/usr/bin/env bash
#
# Captures seeded, deterministic screenshots of KeepFresh for the README.
#
# Drives the iOS Simulator: builds the app, then for each screen launches it
# with -screenshotMode / -screenshotScreen <name> (see ScreenshotRouter in
# SceneDelegate.swift) and grabs a PNG. Home and Items are captured in both
# light and dark appearances to showcase the dynamic-color theming.
#
# Usage:  ./scripts/capture-screenshots.sh
# Output: docs/media/screenshots/<screen>-<appearance>.png
#
set -euo pipefail

SCHEME="KeepFresh"
BUNDLE_ID="com.maria.keepfresh"
DEVICE="iPhone 16e"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="$PROJECT_DIR/build/screenshots-dd"
OUT_DIR="$PROJECT_DIR/docs/media/screenshots"

# Screens captured in light only, and the subset also captured in dark.
LIGHT_SCREENS=(signIn home items addItem itemDetails notifications profile)
DARK_SCREENS=(home items)

mkdir -p "$OUT_DIR"

# Resolve the device's UDID by name (unambiguous for simctl across runtimes).
DEVICE_ID="$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-F-]{36}')"
if [[ -z "$DEVICE_ID" ]]; then
  echo "error: no available simulator named '$DEVICE'" >&2
  exit 1
fi

echo "==> Booting $DEVICE ($DEVICE_ID)"
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$DEVICE_ID" -b

echo "==> Building $SCHEME for simulator"
xcodebuild \
  -project "$PROJECT_DIR/KeepFresh.xcodeproj" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build >/dev/null

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
echo "==> Installing $APP_PATH"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

capture() {
  local screen="$1" appearance="$2"
  xcrun simctl ui "$DEVICE_ID" appearance "$appearance"
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -screenshotMode -screenshotScreen "$screen" >/dev/null
  sleep 3.5
  local out="$OUT_DIR/${screen}-${appearance}.png"
  xcrun simctl io "$DEVICE_ID" screenshot "$out" >/dev/null
  echo "    saved ${out#"$PROJECT_DIR/"}"
}

echo "==> Capturing light screens"
for screen in "${LIGHT_SCREENS[@]}"; do
  capture "$screen" light
done

echo "==> Capturing dark screens"
for screen in "${DARK_SCREENS[@]}"; do
  capture "$screen" dark
done

xcrun simctl ui "$DEVICE_ID" appearance light
echo "==> Done. Screenshots in ${OUT_DIR#"$PROJECT_DIR/"}/"

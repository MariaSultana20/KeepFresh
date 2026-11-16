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

echo "==> Booting $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$DEVICE" -b

echo "==> Building $SCHEME for simulator"
xcodebuild \
  -project "$PROJECT_DIR/KeepFresh.xcodeproj" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  build >/dev/null

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
echo "==> Installing $APP_PATH"
xcrun simctl install "$DEVICE" "$APP_PATH"

capture() {
  local screen="$1" appearance="$2"
  xcrun simctl ui "$DEVICE" appearance "$appearance"
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -screenshotMode -screenshotScreen "$screen" >/dev/null
  sleep 3.5
  local out="$OUT_DIR/${screen}-${appearance}.png"
  xcrun simctl io "$DEVICE" screenshot "$out" >/dev/null
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

xcrun simctl ui "$DEVICE" appearance light
echo "==> Done. Screenshots in ${OUT_DIR#"$PROJECT_DIR/"}/"

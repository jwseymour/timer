#!/bin/bash
# Builds PomodoroUp and wraps it in a minimal .app bundle.
#
# SwiftData requires a real app bundle (Info.plist with a bundle name) to
# initialize its CoreData backing store — a bare `swift run`/`swift build`
# executable crashes at launch with "Unable to determine Bundle Name".
# LSUIElement=true keeps it a menu-bar-only app: no Dock icon, no app switcher
# entry.
set -euo pipefail

CONFIG="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PomodoroUp"
APP_BUNDLE="$ROOT_DIR/.build/$APP_NAME.app"
BINARY_PATH="$ROOT_DIR/.build/$CONFIG/$APP_NAME"

echo "Building ($CONFIG)..."
swift build -c "$CONFIG" --package-path "$ROOT_DIR"

echo "Assembling $APP_BUNDLE ..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.jackseymour.pomodoroup</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "Built: $APP_BUNDLE"

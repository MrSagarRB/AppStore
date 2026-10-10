#!/bin/bash
# Builds a universal MacPulse.app and an installer MacPulse.dmg into ./build.
# Usage: ./build.sh [--install]   (--install also copies the app straight to /Applications)
set -euo pipefail
cd "$(dirname "$0")"

APP="build/MacPulse.app"
VERSION="1.0.0"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MacPulse"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacPulse"

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift ../tools/prepare-icon.swift icon.png iconset "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacPulse</string>
    <key>CFBundleDisplayName</key><string>MacPulse</string>
    <key>CFBundleIdentifier</key><string>io.github.mrsagarrb.MacPulse</string>
    <key>CFBundleExecutable</key><string>MacPulse</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"

scripts/make_dmg.sh

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/MacPulse.app
    cp -R "$APP" /Applications/MacPulse.app
    echo "Installed to /Applications/MacPulse.app"
fi

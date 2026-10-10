#!/bin/bash
# Packages build/MacPulse.app into build/MacPulse.dmg (drag-to-Applications installer).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/MacPulse.app"
DMG="build/MacPulse.dmg"
VOL="MacPulse"
RW="build/MacPulse-rw.dmg"
STAGE="$(mktemp -d)"

[[ -d "$APP" ]] || { echo "Missing $APP — run ./build.sh first"; exit 1; }

# Eject any stale mount from an earlier run.
hdiutil detach "/Volumes/$VOL" -force >/dev/null 2>&1 || true
rm -f "$DMG" "$RW"

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "$VOL" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
hdiutil attach "$RW" -mountpoint "/Volumes/$VOL" -nobrowse -noverify >/dev/null

# Best effort: lay the window out so the app sits next to the Applications shortcut.
# (Needs Finder automation permission; the DMG works fine without it.)
(
osascript <<OSA
tell application "Finder"
    tell disk "$VOL"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 140, 740, 460}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set position of item "MacPulse.app" of container window to {140, 150}
        set position of item "Applications" of container window to {400, 150}
        close
    end tell
end tell
OSA
) >/dev/null 2>&1 &
PID=$!
for _ in $(seq 1 20); do kill -0 $PID 2>/dev/null || break; sleep 1; done
kill $PID 2>/dev/null || true

sync
hdiutil detach "/Volumes/$VOL" -force >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"; rm -rf "$STAGE"
codesign --force --sign - "$DMG" >/dev/null 2>&1 || true
echo "Built $DMG"

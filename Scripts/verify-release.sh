#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
cd "$TASK_ROOT"
MOUNT="$TASK_ROOT/build/verify-volume"
mkdir -p "$MOUNT"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)
DMG="$TASK_ROOT/build/Macut-$VERSION-$ARCH.dmg"
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT" -plist > build/verify-mount.plist
trap 'hdiutil detach "$MOUNT" >/dev/null' EXIT
codesign --verify --deep --strict "$MOUNT/Macut.app"
plutil -lint "$MOUNT/Macut.app/Contents/Info.plist"
cmp "$MOUNT/Macut.app/Contents/MacOS/Macut" build/Macut.app/Contents/MacOS/Macut
cmp "$MOUNT/Macut.app/Contents/Resources/AppIcon.icns" build/Macut.app/Contents/Resources/AppIcon.icns
[[ "$(readlink "$MOUNT/Applications")" == /Applications ]]
echo "PASS mounted app signature, plist, executable and icon match, Applications shortcut"
shasum -a 256 "$DMG"

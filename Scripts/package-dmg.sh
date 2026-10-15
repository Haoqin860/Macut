#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
cd "$TASK_ROOT"
APP="$TASK_ROOT/build/Macut.app"
if [[ ! -d "$APP" ]]; then ./Scripts/build-app.sh; fi
STAGING="$TASK_ROOT/.build/dmg-staging"
mkdir -p "$STAGING"
ditto --noextattr --norsrc --noacl "$APP" "$STAGING/Macut.app"
if [[ ! -L "$STAGING/Applications" ]]; then ln -s /Applications "$STAGING/Applications"; fi
cp -X docs/guide.md "$STAGING/使用说明.md"
xattr -cr "$STAGING/Macut.app"
codesign --verify --deep --strict "$STAGING/Macut.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)
DMG="$TASK_ROOT/build/Macut-$VERSION-$ARCH.dmg"
hdiutil create -volname Macut -srcfolder "$STAGING" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
echo "Packaged: $DMG"

#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
cd "$TASK_ROOT"
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$TASK_ROOT/.build/swift-module-cache"
swift build -c release --product Macut --cache-path "$TASK_ROOT/.build/cache" \
    -Xswiftc -gnone \
    -Xswiftc -file-prefix-map -Xswiftc "$TASK_ROOT=." \
    -Xswiftc -debug-prefix-map -Xswiftc "$TASK_ROOT=."
APP="$TASK_ROOT/build/Macut.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Macut "$APP/Contents/MacOS/Macut"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -X Resources/AppIcon.png "$APP/Contents/Resources/AppIcon.png"
ICONSET="$TASK_ROOT/build/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
xcrun strip -S -x "$APP/Contents/MacOS/Macut"
# Only generated build outputs are cleaned; no installed app or user data is touched.
xattr -cr "$APP"
codesign --force --sign - --identifier app.macut.Macut "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "Built: $APP"

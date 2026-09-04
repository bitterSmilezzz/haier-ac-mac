#!/bin/bash
# 构建 HaierAC.app（打包为可双击运行的 macOS 应用）
# 用法: ./build_app.sh [版本号] [--open]    例: ./build_app.sh 1.3.0 --open
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.3.0"
OPEN=""
for arg in "$@"; do
    case "$arg" in
        --open) OPEN="1" ;;
        *) VERSION="$arg" ;;
    esac
done

echo "🏗 构建 v$VERSION (release)..."
swift build -c release

APP="dist/HaierAC.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/HaierACApp "$APP/Contents/MacOS/HaierACApp"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HaierACApp</string>
    <key>CFBundleIdentifier</key>
    <string>local.haierac.app</string>
    <key>CFBundleName</key>
    <string>海尔空调控制</string>
    <key>CFBundleDisplayName</key>
    <string>海尔空调控制</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"
echo "✅ 构建完成: $APP (v$VERSION)"

ZIP="dist/HaierAC-v${VERSION}-macOS.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "✅ 安装包: $ZIP"

if [ "$OPEN" = "1" ]; then
    open "$APP"
fi

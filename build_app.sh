#!/bin/bash
# 构建 HaierAC.app（打包为可双击运行的 macOS 应用，含桌面小组件扩展）
# 用法: ./build_app.sh [版本号] [--open]    例: ./build_app.sh 1.9.0 --open
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.9.0"
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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns"

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
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>local.haierac.url</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>haierac</string>
            </array>
        </dict>
    </array>
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

# ---- 桌面小组件扩展（WidgetKit）----
WIDGET_APPEX="$APP/Contents/PlugIns/HaierACWidget.appex"
mkdir -p "$WIDGET_APPEX/Contents/MacOS"
cp .build/release/HaierACWidget "$WIDGET_APPEX/Contents/MacOS/HaierACWidget"

cat > "$WIDGET_APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HaierACWidget</string>
    <key>CFBundleIdentifier</key>
    <string>local.haierac.widget</string>
    <key>CFBundleName</key>
    <string>海尔空调小组件</string>
    <key>CFBundleDisplayName</key>
    <string>海尔空调</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
PLIST

# 签名顺序：先签小组件（沙盒 + Application Support 只读例外），再签主 App
# （不带 --deep，使主 App 签名时嵌套代码已就绪并正确记录哈希）。
# 主 App 保持非沙盒、无额外 entitlement（可自由读写文件系统）。
# Widget 的只读例外指向当前用户的 Application Support（动态生成，避免硬编码用户名）
# Widget 的只读例外指向当前用户的 Application Support（动态生成，避免硬编码用户名）
WIDGET_ENTITLEMENTS="$(mktemp -d)/HaierACWidget.entitlements"
cat > "$WIDGET_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
    <array>
        <string>$HOME/Library/Application Support/HaierAC/</string>
    </array>
</dict>
</plist>
PLIST
codesign --force --deep -s - --entitlements "$WIDGET_ENTITLEMENTS" "$WIDGET_APPEX"
codesign --force -s - "$APP"
echo "✅ 构建完成: $APP (v$VERSION, 含小组件)"

ZIP="dist/HaierAC-v${VERSION}-macOS.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "✅ 安装包: $ZIP"

if [ "$OPEN" = "1" ]; then
    open "$APP"
fi

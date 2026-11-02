#!/bin/bash

# 遇到错误立即退出
set -e

# 获取脚本所在目录与项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "=== 开始构建 RedisMenu 应用程序 ==="

# 检查 Redis 二进制文件是否存在
REDIS_DIR="$PROJECT_DIR/RedisMenu/Resources/redis"
if [ ! -d "$REDIS_DIR" ] || [ ! -f "$REDIS_DIR/bin/redis-server" ]; then
    echo "未检测到已准备的 Redis 二进制文件，正在执行准备/下载脚本..."
    "$SCRIPT_DIR/download_redis.sh"
fi

# 清理旧的构建产物
echo "正在清理先前的构建产物..."
rm -rf "$PROJECT_DIR/build"

APP_BUNDLE_DIR="$PROJECT_DIR/build/Release/RedisMenu.app"
mkdir -p "$APP_BUNDLE_DIR/Contents/MacOS"
mkdir -p "$APP_BUNDLE_DIR/Contents/Resources"

# 检查是否有完整版 Xcode 支持 xcodebuild
USE_XCODEBUILD=false
if command -v xcodebuild >/dev/null 2>&1; then
    if xcodebuild -version >/dev/null 2>&1; then
        USE_XCODEBUILD=true
    fi
fi

if [ "$USE_XCODEBUILD" = true ]; then
    echo "检测到 Xcode 环境，正在使用 xcodebuild 编译..."
    cd "$PROJECT_DIR"
    xcodebuild -project RedisMenu.xcodeproj -scheme RedisMenu -configuration Release -derivedDataPath "$PROJECT_DIR/build/DerivedData" build
    
    # 拷贝编译出的 App 到 build/Release/
    BUILT_APP=$(find "$PROJECT_DIR/build/DerivedData" -name "RedisMenu.app" -type d | head -n 1)
    if [ -n "$BUILT_APP" ]; then
        cp -R "$BUILT_APP" "$PROJECT_DIR/build/Release/"
    fi
else
    echo "当前为 Command Line Tools 环境，正在使用 swiftc 直接编译并打包应用..."
    
    # 收集所有 Swift 源文件
    SWIFT_FILES=$(find "$PROJECT_DIR/RedisMenu" -name "*.swift")
    
    # 使用 swiftc 进行编译
    swiftc $SWIFT_FILES -o "$APP_BUNDLE_DIR/Contents/MacOS/RedisMenu"
    
    # 创建 Info.plist
    cat > "$APP_BUNDLE_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RedisMenu</string>
    <key>CFBundleIdentifier</key>
    <string>com.maquina-app.RedisMenu</string>
    <key>CFBundleName</key>
    <string>RedisMenu</string>
    <key>CFBundleDisplayName</key>
    <string>RedisMenu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

    # 拷贝资源文件（Redis 二进制及配置文件）
    echo "正在复制 Redis 资源文件到 App 包中..."
    cp -R "$REDIS_DIR" "$APP_BUNDLE_DIR/Contents/Resources/"
    chmod +x "$APP_BUNDLE_DIR/Contents/Resources/redis/bin/"*

    # 拷贝图标等资源
    if [ -f "$PROJECT_DIR/RedisMenu/Assets.xcassets/MenuBarIcon.imageset/redis.svg" ]; then
        cp "$PROJECT_DIR/RedisMenu/Assets.xcassets/MenuBarIcon.imageset/redis.svg" "$APP_BUNDLE_DIR/Contents/Resources/MenuBarIcon.svg"
    fi
    if [ -f "$PROJECT_DIR/RedisMenu/Assets.xcassets/CompanyLogo.imageset/Maquina Logo.svg" ]; then
        cp "$PROJECT_DIR/RedisMenu/Assets.xcassets/CompanyLogo.imageset/Maquina Logo.svg" "$APP_BUNDLE_DIR/Contents/Resources/CompanyLogo.svg"
    fi
fi

# 检查构建结果
if [ -d "$APP_BUNDLE_DIR" ] && [ -f "$APP_BUNDLE_DIR/Contents/MacOS/RedisMenu" ]; then
    echo "======================================"
    echo "✅ 构建成功完成！"
    echo "应用程序路径: $APP_BUNDLE_DIR"
    echo "======================================"
else
    echo "❌ 构建失败，请检查上方日志排查错误。"
    exit 1
fi

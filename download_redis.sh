#!/bin/bash

# 遇到任何错误立即退出
set -e

# 定义 Redis 版本（默认最新稳定版 stable，支持 Redis 8.x）
DEFAULT_REDIS_VERSION="stable"
REDIS_VERSION=${1:-$DEFAULT_REDIS_VERSION}

# 脚本与项目路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
RESOURCES_DIR="$PROJECT_DIR/RedisMenu/Resources"
DEST_DIR="$RESOURCES_DIR/redis"

echo "=== Redis 二进制准备程序 ==="

# 优先检查本地已有 Redis 安装（例如 /Users/arona/tools/redis 或环境变量指定的路径）
LOCAL_CANDIDATE_PATHS=(
    "${REDIS_LOCAL_DIR:-}"
    "/Users/arona/tools/redis"
    "$HOME/tools/redis"
)

FOUND_LOCAL=""
for candidate in "${LOCAL_CANDIDATE_PATHS[@]}"; do
    if [ -n "$candidate" ] && [ -f "$candidate/src/redis-server" ]; then
        FOUND_LOCAL="$candidate"
        break
    elif [ -n "$candidate" ] && [ -f "$candidate/bin/redis-server" ]; then
        FOUND_LOCAL="$candidate"
        break
    fi
done

if [ -n "$FOUND_LOCAL" ] && [ "$REDIS_VERSION" == "stable" -o "$REDIS_VERSION" == "local" ]; then
    echo "检测到本地已安装/编译的 Redis: $FOUND_LOCAL"
    mkdir -p "$DEST_DIR/bin"
    
    # 拷贝二进制文件
    BIN_DIR="$FOUND_LOCAL/src"
    [ ! -d "$BIN_DIR" ] && BIN_DIR="$FOUND_LOCAL/bin"
    
    for binary in redis-server redis-cli redis-sentinel redis-benchmark redis-check-aof redis-check-rdb; do
        if [ -f "$BIN_DIR/$binary" ]; then
            cp "$BIN_DIR/$binary" "$DEST_DIR/bin/"
        fi
    done
    
    # 拷贝配置文件
    [ -f "$FOUND_LOCAL/redis.conf" ] && cp "$FOUND_LOCAL/redis.conf" "$DEST_DIR/"
    [ -f "$FOUND_LOCAL/sentinel.conf" ] && cp "$FOUND_LOCAL/sentinel.conf" "$DEST_DIR/"
    
    chmod +x "$DEST_DIR/bin/"*
    
    DETECTED_VERSION=$("$DEST_DIR/bin/redis-server" --version 2>/dev/null | grep -o 'v=[0-9.]*' | cut -d= -f2 || echo "8.x")
    echo "✅ 已成功从本地拷贝 Redis (版本 $DETECTED_VERSION) 到资源目录: $DEST_DIR"
    exit 0
fi

# 如果未找到本地已编译版本，则自动下载最新稳定版并编译
if [ "$REDIS_VERSION" == "stable" ]; then
    echo "正在获取最新的 Redis 稳定版本号..."
    REDIS_VERSION=$(curl -sL https://download.redis.io/redis-stable/00-RELEASENOTES | grep -o 'Redis [0-9.]* *Released' | head -n 1 | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
    if [ -z "$REDIS_VERSION" ]; then
        REDIS_VERSION="8.10.2"
    fi
fi

echo "使用 Redis 版本: $REDIS_VERSION"

# 检查 CPU 架构
if [[ $(uname -m) == 'arm64' ]]; then
    ARCH="arm64 (Apple Silicon)"
else
    ARCH="x86_64 (Intel)"
fi

REDIS_URL="https://download.redis.io/releases/redis-$REDIS_VERSION.tar.gz"
TMP_DIR="$PROJECT_DIR/tmp"
TARBALL="$TMP_DIR/redis-$REDIS_VERSION.tar.gz"
EXTRACTED_DIR="$TMP_DIR/redis-$REDIS_VERSION"

echo "当前架构: $ARCH"
echo "下载地址: $REDIS_URL"

# 创建临时下载目录
mkdir -p "$TMP_DIR"

# 下载源码包
echo "正在下载 Redis $REDIS_VERSION..."
curl -sL -o "$TARBALL" "$REDIS_URL"

# 解压源码包
echo "正在解压 Redis..."
tar -xzf "$TARBALL" -C "$TMP_DIR"

# 创建资源目录
mkdir -p "$RESOURCES_DIR"

# 编译 Redis（在 macOS 上使用 libc malloc 与并行多核编译）
echo "正在编译 Redis..."
cd "$EXTRACTED_DIR"
NCPU=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
make MALLOC=libc -j"$NCPU"

# 创建目标目录
mkdir -p "$DEST_DIR"
mkdir -p "$DEST_DIR/bin"

# 复制编译后的二进制文件
echo "正在复制二进制文件到 $DEST_DIR..."
for binary in redis-server redis-cli redis-sentinel redis-benchmark redis-check-aof redis-check-rdb; do
    if [ -f "src/$binary" ]; then
        cp "src/$binary" "$DEST_DIR/bin/"
    fi
done

# 复制配置文件
[ -f "redis.conf" ] && cp "redis.conf" "$DEST_DIR/"
[ -f "sentinel.conf" ] && cp "sentinel.conf" "$DEST_DIR/"

# 赋予执行权限
echo "正在设置可执行权限..."
chmod +x "$DEST_DIR/bin/"*

# 清理临时文件
echo "清理临时编译文件..."
rm -rf "$TMP_DIR"

echo "✅ Redis $REDIS_VERSION 已成功下载、编译并准备就绪。"
echo "存放路径: $DEST_DIR"

#!/bin/bash

# Exit on any error
set -e

# Define Redis version (defaults to latest stable if not specified)
DEFAULT_REDIS_VERSION="stable"
REDIS_VERSION=${1:-$DEFAULT_REDIS_VERSION}

# If using stable, get the actual version number
if [ "$REDIS_VERSION" == "stable" ]; then
	echo "Fetching latest stable Redis version..."
	REDIS_VERSION=$(curl -s http://download.redis.io/redis-stable/00-RELEASENOTES | grep -o 'Redis .* Released' | head -n 1 | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
fi

echo "Using Redis version $REDIS_VERSION"

# Define URLs and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/RedisMenu/Resources"

# Redis doesn't have separate architecture builds for macOS, but we'll check architecture for future compatibility
if [[ $(uname -m) == 'arm64' ]]; then
	ARCH="arm64"
else
	ARCH="x86_64"
fi

REDIS_URL="http://download.redis.io/releases/redis-$REDIS_VERSION.tar.gz"
TMP_DIR="$PROJECT_DIR/tmp"
TARBALL="$TMP_DIR/redis-$REDIS_VERSION.tar.gz"
EXTRACTED_DIR="$TMP_DIR/redis-$REDIS_VERSION"
DEST_DIR="$RESOURCES_DIR/redis"

echo "Architecture: $ARCH"
echo "Redis URL: $REDIS_URL"

# Create temp directory
mkdir -p "$TMP_DIR"

# Download Redis tarball
echo "Downloading Redis $REDIS_VERSION..."
curl -o "$TARBALL" "$REDIS_URL"

# Extract tarball
echo "Extracting Redis..."
tar -xzf "$TARBALL" -C "$TMP_DIR"

# Create Resources directory if it doesn't exist
mkdir -p "$RESOURCES_DIR"

# Compile Redis
echo "Compiling Redis..."
cd "$EXTRACTED_DIR"
make MALLOC=libc -j$(nproc) # Use libc malloc and parallel compilation

# Create destination directory
mkdir -p "$DEST_DIR"
mkdir -p "$DEST_DIR/bin"

# Copy compiled binaries to destination
echo "Copying files to $DEST_DIR..."
for binary in redis-server redis-cli redis-sentinel redis-benchmark redis-check-aof redis-check-rdb; do
	if [ -f "src/$binary" ]; then
		cp "src/$binary" "$DEST_DIR/bin/"
	fi
done

# Copy configuration files
cp "redis.conf" "$DEST_DIR/"
cp "sentinel.conf" "$DEST_DIR/"

# Make binaries executable
echo "Setting executable permissions..."
chmod +x "$DEST_DIR/bin/"*

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo "✅ Redis $REDIS_VERSION has been downloaded, compiled, and prepared successfully."
echo "Location: $DEST_DIR"

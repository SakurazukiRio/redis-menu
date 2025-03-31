#!/bin/bash

# Exit on any error
set -e

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if Redis binaries exist
REDIS_DIR="$PROJECT_DIR/RedisMenu/Resources/redis"
if [ ! -d "$REDIS_DIR" ] || [ ! -f "$REDIS_DIR/bin/redis-server" ]; then
	echo "Redis binaries not found. Running download script first..."
	"$SCRIPT_DIR/download-redis.sh"
fi

# Clean previous build
echo "Cleaning previous build..."
rm -rf "$PROJECT_DIR/build"

# Build the app
echo "Building RedisMenu app..."
cd "$PROJECT_DIR"
xcodebuild -project RedisMenu.xcodeproj -scheme RedisMenu -configuration Release build

# Check if build was successful
if [ -d "$PROJECT_DIR/build/Release/RedisMenu.app" ]; then
	echo "✅ Build completed successfully!"
	echo "App location: $PROJECT_DIR/build/Release/RedisMenu.app"

	# Option to open the folder containing the app
	read -p "Do you want to open the folder containing the app? (y/n) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		open "$PROJECT_DIR/build/Release"
	fi
else
	echo "❌ Build failed. Check the logs above for errors."
	exit 1
fi

#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "💧 Building AquaFlow for macOS..."

APP_NAME="AquaFlow"
BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

SDK_PATH=$(xcrun --show-sdk-path)

echo "Compiling Swift sources..."
swiftc \
  -O \
  -parse-as-library \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx12.0 \
  -framework Cocoa \
  -framework SwiftUI \
  -framework UserNotifications \
  Sources/*.swift \
  -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Copying metadata and assets..."
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "Signing application bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ AquaFlow built successfully at: $APP_BUNDLE"

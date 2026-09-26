#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

BUILD_DIR="$DIR/build"
APP_BUNDLE="$BUILD_DIR/AquaFlow.app"

if [ ! -d "$APP_BUNDLE" ]; then
  "$DIR/scripts/build.sh"
fi

echo "💧 Stopping previous AquaFlow instance if running..."
pkill -x AquaFlow 2>/dev/null || true
sleep 0.5

echo "🚀 Launching AquaFlow in menu bar..."
open -n "$APP_BUNDLE"

echo "✨ AquaFlow is running! Check the water drop icon (💧) in your macOS menu bar."

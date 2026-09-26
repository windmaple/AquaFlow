#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "🧹 Cleaning build artifacts..."
rm -rf "$DIR/build"
echo "✅ Build artifacts removed."

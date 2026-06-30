#!/bin/bash
# install_macos.sh
# Build and install the Branched Git Client for macOS.

set -e

echo "=== Starting Branched Git Client Build & Install for macOS ==="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "Warning: This script is designed to run on macOS (detected $OSTYPE)."
  echo "We will outline the commands, but compilation may fail on non-macOS systems."
fi

echo "1. Resolving dependencies..."
flutter pub get

echo "2. Building release copy for macOS..."
flutter build macos --release

SRC_PATH="build/macos/Build/Products/Release/branched.app"
DEST_PATH="/Applications/branched.app"

if [ -d "$SRC_PATH" ]; then
  echo "3. Installing application to $DEST_PATH..."
  # Clean up existing installation if present
  if [ -d "$DEST_PATH" ]; then
    echo "Removing previous installation at $DEST_PATH..."
    rm -rf "$DEST_PATH"
  fi
  
  # Copy application bundle to Applications folder
  cp -R "$SRC_PATH" "$DEST_PATH"
  echo "=== Installation successful! You can now launch 'branched' from your Applications or Spotlight. ==="
else
  echo "Error: Could not find built application bundle at $SRC_PATH"
  exit 1
fi

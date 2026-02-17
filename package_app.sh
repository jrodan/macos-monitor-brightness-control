#!/bin/bash

# Configuration
APP_NAME="BrightnessControl"
BUILD_PATH=".build/apple/Products/Release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building for Release..."
swift build -c release

# Get the binary path dynamically
BINARY_PATH=$(swift build -c release --show-bin-path)/$APP_NAME

# Create folder structure
echo "Creating .app bundle structure..."
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BINARY_PATH" "$MACOS/"

# Copy Info.plist (though it's embedded, keeping it here is standard practice)
cp "Sources/BrightnessControl/Info.plist" "$CONTENTS/"

# Copy resources from the build bundle to the main app resources folder
echo "Copying resources..."
BUILD_BUNDLE_PATH=$(find .build -name "${APP_NAME}_${APP_NAME}.bundle" -type d | head -n 1)
if [ -d "$BUILD_BUNDLE_PATH" ]; then
    cp -R "$BUILD_BUNDLE_PATH/"* "$RESOURCES/"
fi

# Manual backup copy of crucial resources (just in case SPM packaging misses them)
if [ -f "Sources/BrightnessControl/MainAppIcon.icns" ]; then
    cp "Sources/BrightnessControl/MainAppIcon.icns" "$RESOURCES/"
fi
if [ -f "Sources/BrightnessControl/intro.txt" ]; then
    cp "Sources/BrightnessControl/intro.txt" "$RESOURCES/"
fi

# Sign the app (with entitlements for hardened runtime capability)
echo "Signing the app..."
codesign --force --deep --options runtime --entitlements "Sources/BrightnessControl/BrightnessControl.entitlements" --sign - "$APP_BUNDLE"

echo "Success! Your app is ready at $PWD/$APP_BUNDLE"

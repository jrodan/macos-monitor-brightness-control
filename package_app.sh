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

# Compile Assets (if any)
if [ -d "Sources/BrightnessControl/Assets.xcassets" ]; then
    echo "Compiling assets..."
    xcrun actool "Sources/BrightnessControl/Assets.xcassets" --compile "$RESOURCES" --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon --output-format xml1
fi

# Sign the app (with entitlements for hardened runtime capability)
echo "Signing the app..."
codesign --force --deep --options runtime --entitlements "Sources/BrightnessControl/BrightnessControl.entitlements" --sign - "$APP_BUNDLE"

echo "Success! Your app is ready at $PWD/$APP_BUNDLE"

#!/bin/bash

# Configuration
APP_NAME="BrightnessControl"
ZIP_NAME="$APP_NAME.zip"
GITHUB_USER="jrodan"
GITHUB_REPO="brightness-control-macos"

# 1. Build and package the app first
echo "--- Step 1: Building and Packaging App ---"
chmod +x package_app.sh
./package_app.sh

if [ ! -d "$APP_NAME.app" ]; then
    echo "Error: $APP_NAME.app not found. Build failed?"
    exit 1
fi

# 2. Extract version from Info.plist
if [ -n "$GITHUB_REF_NAME" ] && [[ "$GITHUB_REF_NAME" == v* ]]; then
    VERSION=${GITHUB_REF_NAME#v}
else
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PWD/$APP_NAME.app/Contents/Info.plist")
fi
echo "--- Identified Version: $VERSION ---"

# 3. Create the ZIP for release
echo "--- Step 2: Creating $ZIP_NAME ---"
rm -f "$ZIP_NAME"
zip -ry "$ZIP_NAME" "$APP_NAME.app" > /dev/null

# 4. Calculate SHA256
SHA256=$(shasum -a 256 "$ZIP_NAME" | awk '{print $1}')
echo "--- SHA256 Hash: $SHA256 ---"

# 5. Generate Homebrew Cask file
CASK_FILE="brightness-control.rb"
echo "--- Step 3: Generating $CASK_FILE ---"

cat <<EOF > "$CASK_FILE"
cask "brightness-control" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/jrodan/brightness-control-macos/releases/download/v#{version}/BrightnessControl.zip"
  name "Brightness Control"
  desc "DDC/CI and Hybrid Software Brightness Control for macOS"
  homepage "https://github.com/jrodan/brightness-control-macos"

  app "BrightnessControl.app"

  zap trash: [
    "~/Library/Preferences/com.user.BrightnessControl.plist",
    "~/Library/Application Support/BrightnessControl",
  ]
end
EOF

echo ""
echo "--- FINISHED ---"
echo "1. Upload '$ZIP_NAME' to a GitHub Release tagged 'v$VERSION'."
echo "2. Copy '$CASK_FILE' to your Homebrew Tap (e.g., homebrew-tap/Casks/)."
echo ""
echo "You can now distribute the app via Homebrew!"

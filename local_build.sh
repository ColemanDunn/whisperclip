#!/usr/bin/env bash
set -euo pipefail

CONFIG=${1:-Release}
BUILD_DIR="build"
VERSION=$(cat version)
APP_NAME="WhisperClip"
APP_BUNDLE_PATH="$BUILD_DIR/$APP_NAME.app"
APP_ICON="WhisperClip.icns"
APP_BUNDLE_IDENTIFIER="com.whisperclip"
CONFIG_PRODUCT_PATH="$BUILD_DIR/Build/Products/$CONFIG"
BINARY_PATH="$CONFIG_PRODUCT_PATH/$APP_NAME"
ENTITLEMENTS_PATH="WhisperClip.entitlements"

xcodebuild \
  -scheme "$APP_NAME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS=arm64 \
  build

# Build an app-style bundle so you can launch it directly from Finder or Applications.
rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS" "$APP_BUNDLE_PATH/Contents/Resources"
cp "$BINARY_PATH" "$APP_BUNDLE_PATH/Contents/MacOS/$APP_NAME"
cp "$APP_ICON" "$APP_BUNDLE_PATH/Contents/Resources/$APP_NAME.icns"

MLX_BUNDLE="$CONFIG_PRODUCT_PATH/mlx-swift_Cmlx.bundle"
if [[ -d "$MLX_BUNDLE" ]]; then
  cp -R "$MLX_BUNDLE" "$APP_BUNDLE_PATH/Contents/Resources/"
fi

cat > "$APP_BUNDLE_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_BUNDLE_IDENTIFIER}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>LSRequiresNativeExecution</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>${APP_NAME} needs access to your microphone for transcription.</string>
    <key>NSPasteboardUsageDescription</key>
    <string>${APP_NAME} needs clipboard access to paste transcribed text.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>${APP_NAME} needs accessibility permissions for global hotkeys.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>${APP_NAME} needs permission to control System Events for clipboard operations.</string>
</dict>
</plist>
EOF

# Sign the local app bundle so TCC (Accessibility/Microphone) can track it reliably.
codesign --force \
  --deep \
  --sign - \
  --identifier "$APP_BUNDLE_IDENTIFIER" \
  --entitlements "$ENTITLEMENTS_PATH" \
  "$APP_BUNDLE_PATH"

codesign --verify --verbose=2 "$APP_BUNDLE_PATH"

echo "✅ Built binary: $BINARY_PATH"
echo "✅ Built app bundle: $APP_BUNDLE_PATH"

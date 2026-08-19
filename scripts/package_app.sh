#!/bin/bash
set -e

VERSION="0.10.3"
echo "=== Building Integra v$VERSION (Native Swift & Clean Drag-and-Drop DMG) ==="
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Integra.app"
VOL_NAME="Integra"
DMG_PATH="$DIST_DIR/Integra-v$VERSION.dmg"
TMP_DMG="$DIST_DIR/temp.dmg"

cd "$PROJECT_DIR"

# Clean any existing mounts
hdiutil detach "/Volumes/$VOL_NAME" 2>/dev/null || true
hdiutil detach "/Volumes/$VOL_NAME Installer" 2>/dev/null || true

echo "--> Running Automated Test Suite..."
./scripts/run_tests.sh

echo "--> Compiling Swift Release Binary..."
swift build -c release

RELEASE_BIN="$PROJECT_DIR/.build/release/Integra"
RELEASE_MCP_BIN="$PROJECT_DIR/.build/release/integra-mcp"

if [ ! -f "$RELEASE_BIN" ]; then
    echo "Error: Compiled binary not found at $RELEASE_BIN"
    exit 1
fi

if [ ! -f "$RELEASE_MCP_BIN" ]; then
    echo "Error: Compiled MCP binary not found at $RELEASE_MCP_BIN"
    exit 1
fi

echo "--> Constructing macOS App Bundle ($APP_BUNDLE)..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/Integra"
chmod +x "$APP_BUNDLE/Contents/MacOS/Integra"

cp "$RELEASE_MCP_BIN" "$APP_BUNDLE/Contents/MacOS/integra-mcp"
chmod +x "$APP_BUNDLE/Contents/MacOS/integra-mcp"

# Install local binary helper
mkdir -p "$HOME/.local/bin"
cp "$RELEASE_MCP_BIN" "$HOME/.local/bin/integra-mcp"
chmod +x "$HOME/.local/bin/integra-mcp"

if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    echo "--> Copying AppIcon.icns to App Bundle..."
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat << EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Integra</string>
    <key>CFBundleExecutable</key>
    <string>Integra</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.integra.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Integra</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Integra</string>
</dict>
</plist>
EOF

# App Bundle Code Signing with Hardened Runtime (H-1 Fix)
if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    echo "--> Signing App Bundle with Developer ID: $DEVELOPER_ID_APPLICATION..."
    codesign --force --options runtime --deep --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
else
    echo "--> Signing App Bundle (Ad-hoc with Hardened Runtime)..."
    codesign --force --options runtime --deep --sign - "$APP_BUNDLE"
fi

if [ ! -f "$PROJECT_DIR/Resources/dmg_background.png" ]; then
    echo "--> Generating Clean 540x360 DMG Background Graphic..."
    python3 "$PROJECT_DIR/scripts/generate_dmg_background.py"
else
    echo "--> Preserving custom DMG Background Graphic (Resources/dmg_background.png)..."
fi

echo "--> Creating Interactive Drag-and-Drop Disk Image..."
rm -f "$DMG_PATH" "$TMP_DMG"

# Create a temporary writable DMG
hdiutil create -size 35m -fs HFS+ -volname "$VOL_NAME" "$TMP_DMG" > /dev/null

MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG")
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -n 1)

if [ -z "$MOUNT_DIR" ]; then
    echo "Error: Failed to mount temporary DMG"
    exit 1
fi

echo "--> Copying files to DMG Volume ($MOUNT_DIR)..."
cp -R "$APP_BUNDLE" "$MOUNT_DIR/"
mkdir -p "$MOUNT_DIR/.background"
cp "$PROJECT_DIR/Resources/dmg_background.png" "$MOUNT_DIR/.background/background.png"
ln -s /Applications "$MOUNT_DIR/Applications"

echo "--> Applying AppleScript Finder Window Styling..."
osascript << EOF || true
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 740, 510}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "Integra.app" of container window to {140, 175}
        set position of item "Applications" of container window to {400, 175}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR" -force > /dev/null

echo "--> Finalizing Compressed Release DMG ($DMG_PATH)..."
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" > /dev/null
rm -f "$TMP_DMG"

# DMG Code Signing and Notarization (H-1 Fix)
if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    echo "--> Signing Disk Image with Developer ID ($DMG_PATH)..."
    codesign --force --sign "$DEVELOPER_ID_APPLICATION" "$DMG_PATH"
    
    if [ -n "$APPLE_ID" ] && [ -n "$APP_PASSWORD" ] && [ -n "$TEAM_ID" ]; then
        echo "--> Submitting to Apple Notary Service..."
        xcrun notarytool submit "$DMG_PATH" --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID" --wait
        xcrun stapler staple "$DMG_PATH"
        echo "--> Stapled notarization ticket to $DMG_PATH"
    fi
fi

echo "--> Creating Distribution ZIP ($DIST_DIR/Integra-v$VERSION.zip)..."
cd "$DIST_DIR"
zip -q -r "Integra-v$VERSION.zip" "Integra.app"

echo "=== Build and Packaging Complete! ==="
echo "Artifacts generated:"
echo " - App Bundle: $APP_BUNDLE"
echo " - Disk Image: $DMG_PATH (Drag-and-Drop Clean Layout)"
echo " - ZIP Archive: $DIST_DIR/Integra-v$VERSION.zip"

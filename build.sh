#!/bin/bash
set -euo pipefail

APP_NAME="Usher"
BUNDLE_ID="com.serhii.usher"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Applications/$APP_NAME.app"
CONFIG_DIR="$HOME/.config/usher"

echo "==> Stopping any running instance"
pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true

echo "==> Compiling"
BIN="$SRC_DIR/.build/$APP_NAME"
mkdir -p "$SRC_DIR/.build"
swiftc -O "$SRC_DIR/Sources/main.swift" -o "$BIN"

echo "==> Assembling app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
[ -f "$SRC_DIR/Usher.icns" ] && cp "$SRC_DIR/Usher.icns" "$APP_DIR/Contents/Resources/Usher.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>Usher</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>Web URL</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>CFBundleURLSchemes</key>
            <array><string>http</string><string>https</string></array>
        </dict>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array><string>public.html</string><string>public.xhtml</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "==> Seeding config in $CONFIG_DIR (existing files kept)"
mkdir -p "$CONFIG_DIR"
[ -f "$CONFIG_DIR/work-domains.txt" ] || cp "$SRC_DIR/work-domains.txt" "$CONFIG_DIR/work-domains.txt"
[ -f "$CONFIG_DIR/work-apps.txt" ]    || cp "$SRC_DIR/work-apps.txt"    "$CONFIG_DIR/work-apps.txt"
[ -f "$CONFIG_DIR/config" ]           || cp "$SRC_DIR/config"           "$CONFIG_DIR/config"

echo "==> Registering with LaunchServices"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_DIR"

echo "==> Launching agent"
open "$APP_DIR"

echo ""
echo "Done. Final step (one time):"
echo "  System Settings -> Desktop & Dock -> Default web browser -> pick \"$APP_NAME\""
echo "  (or run: ./set-default.sh)"
echo ""
echo "Edit routing anytime (no rebuild needed):"
echo "  $CONFIG_DIR/work-domains.txt   work-apps.txt   config"
echo "Debug log:  ~/.local/state/usher/log"

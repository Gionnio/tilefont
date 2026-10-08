#!/bin/bash
# Compila l'app SwiftUI e crea build/Tilefont.app.
# Requisiti: Xcode Command Line Tools (Swift 5.9+), macOS 14+.
#
# Uso: ./build_app.sh            → build/Tilefont.app
#      ./build_app.sh --install  → anche installata in /Applications e avviata
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Tilefont.app"
VERSION="1.0.1"
BUILD_NUMBER="2"

mkdir -p "$BUILD"

echo "▸ App SwiftUI"
(cd app && swift build -c release)
BIN_DIR="$(cd app && swift build -c release --show-bin-path)"

echo "▸ Bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Tilefont" "$APP/Contents/MacOS/Tilefont"
# Lingue: italiano (base, le chiavi sono il testo italiano) e inglese
cp -R "$ROOT/app/Resources/"*.lproj "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Tilefont</string>
    <key>CFBundleDisplayName</key><string>Tilefont</string>
    <key>CFBundleIdentifier</key><string>com.github.gionnio.Tilefont</string>
    <key>CFBundleExecutable</key><string>Tilefont</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>CFBundleDevelopmentRegion</key><string>it</string>
    <key>CFBundleLocalizations</key><array><string>it</string><string>en</string></array>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Font</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Alternate</string>
            <key>LSItemContentTypes</key><array><string>public.font</string></array>
        </dict>
    </array>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Gionnio. MIT License.</string>
</dict>
</plist>
PLIST

# Icona: rigenerata con iconutil dall'iconset (icon/), altrimenti AppIcon.icns già pronto
ICNS="$BUILD/AppIcon.icns"
if [ -d "$ROOT/icon/AppIcon.iconset" ] && command -v iconutil >/dev/null; then
    iconutil -c icns "$ROOT/icon/AppIcon.iconset" -o "$ICNS"
elif [ -f "$ROOT/AppIcon.icns" ]; then
    cp "$ROOT/AppIcon.icns" "$ICNS"
fi
if [ -f "$ICNS" ]; then
    cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi

codesign --force --deep --sign - "$APP" >/dev/null
touch "$APP" # forza il Finder/Dock a rileggere l'icona
echo "✅ $APP"

if [ "${1:-}" = "--install" ]; then
    echo "▸ Installo in /Applications"
    osascript -e 'quit app "Tilefont"' 2>/dev/null || true
    sleep 1
    rm -rf /Applications/Tilefont.app
    cp -R "$APP" /Applications/
    codesign --force --deep --sign - /Applications/Tilefont.app >/dev/null
    open /Applications/Tilefont.app
    echo "✓ Tilefont installata."
fi

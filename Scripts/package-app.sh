#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Room Light Sensor}"
EXECUTABLE_NAME="RoomLightSensor"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.example.room-light-sensor}"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS="${ARCHS:-arm64 x86_64}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

BUILD_DIR="$ROOT_DIR/.build/package"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_STAGING_DIR="$BUILD_DIR/dmg-root"
DMG_PATH="$BUILD_DIR/$APP_NAME-$APP_VERSION.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

BUILT_BINARIES=()
for ARCH in $ARCHS; do
    swift build \
        --package-path "$ROOT_DIR" \
        -c release \
        --arch "$ARCH" \
        --product "$EXECUTABLE_NAME"
    BUILT_BINARIES+=("$ROOT_DIR/.build/$ARCH-apple-macosx/release/$EXECUTABLE_NAME")
done

if [ "${#BUILT_BINARIES[@]}" -eq 1 ]; then
    cp "${BUILT_BINARIES[0]}" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
else
    lipo -create "${BUILT_BINARIES[@]}" -output "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
fi

cp "$ROOT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"

if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
else
    codesign --force --sign - "$APP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING_DIR" -ov -format UDZO "$DMG_PATH"

if [ -n "$SIGN_IDENTITY" ]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
fi

echo "$DMG_PATH"

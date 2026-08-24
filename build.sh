#!/bin/bash
set -euo pipefail
APP=PoolWebTest
BUILD="$PWD/build"
APPDIR="$BUILD/Payload/$APP.app"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
rm -rf "$BUILD"
mkdir -p "$APPDIR"
xcrun --sdk iphoneos clang \
  -arch arm64 \
  -miphoneos-version-min=15.0 \
  -fobjc-arc \
  -fmodules \
  -isysroot "$SDK" \
  main.m \
  -o "$APPDIR/$APP" \
  -framework UIKit \
  -framework Foundation \
  -framework WebKit
cp Info.plist "$APPDIR/Info.plist"
codesign --force --sign - --timestamp=none "$APPDIR/$APP" || true
cd "$BUILD"
zip -qry "$APP.ipa" Payload
echo "Built $BUILD/$APP.ipa"

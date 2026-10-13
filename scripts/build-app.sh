#!/bin/zsh
# Builds ContextRecorder.app and signs it with a stable identity so macOS keeps
# Screen Recording / Microphone / Automation permissions across rebuilds.
set -euo pipefail
cd "${0:A:h}/.."

IDENTITY="${CODESIGN_IDENTITY:-RegionShot Local Development}"
APP="build/ContextRecorder.app"

swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ContextRecorder "$APP/Contents/MacOS/ContextRecorder"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp scripts/process_session.py scripts/viewer.html "$APP/Contents/Resources/"

codesign --force --sign "$IDENTITY" --identifier com.byronwall.ContextRecorder "$APP"
codesign --verify --verbose=1 "$APP"
echo "Built $APP"

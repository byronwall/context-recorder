#!/usr/bin/env bash
# Builds "Context Recorder.app" and signs it with a stable identity so macOS keeps
# Screen Recording / Microphone / Automation permissions across rebuilds.
# Then installs a copy to /Applications (override with INSTALL_DIR, or set
# INSTALL_DIR= to skip).
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${CODESIGN_IDENTITY:-RegionShot Local Development}"
# Launchers such as Raycast and Spotlight show the bundle file name, so it has the space.
APP_NAME="Context Recorder.app"
APP="build/$APP_NAME"
INSTALL_DIR="${INSTALL_DIR-/Applications}"

swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ContextRecorder "$APP/Contents/MacOS/ContextRecorder"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp scripts/process_session.py scripts/viewer.html "$APP/Contents/Resources/"

codesign --force --sign "$IDENTITY" --identifier com.byronwall.ContextRecorder "$APP"
codesign --verify --verbose=1 "$APP"
echo "Built $APP"

if [ -n "$INSTALL_DIR" ]; then
  if pgrep -xq ContextRecorder; then
    echo "Note: ContextRecorder is running; quit and reopen it to use the new build."
  fi
  # Older builds were installed as ContextRecorder.app; remove that copy too.
  rm -rf "$INSTALL_DIR/ContextRecorder.app" "$INSTALL_DIR/$APP_NAME"
  ditto "$APP" "$INSTALL_DIR/$APP_NAME"
  # Ask Launch Services/Spotlight to pick up the new name and icon right away.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_DIR/$APP_NAME" || true
  touch "$INSTALL_DIR/$APP_NAME"
  echo "Installed $INSTALL_DIR/$APP_NAME"
fi

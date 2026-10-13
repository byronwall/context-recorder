#!/usr/bin/env bash
# Builds ContextRecorder.app and signs it with a stable identity so macOS keeps
# Screen Recording / Microphone / Automation permissions across rebuilds.
# Then installs a copy to /Applications (override with INSTALL_DIR, or set
# INSTALL_DIR= to skip).
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${CODESIGN_IDENTITY:-RegionShot Local Development}"
APP="build/ContextRecorder.app"
INSTALL_DIR="${INSTALL_DIR-/Applications}"

swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ContextRecorder "$APP/Contents/MacOS/ContextRecorder"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp scripts/process_session.py scripts/viewer.html "$APP/Contents/Resources/"

codesign --force --sign "$IDENTITY" --identifier com.byronwall.ContextRecorder "$APP"
codesign --verify --verbose=1 "$APP"
echo "Built $APP"

if [ -n "$INSTALL_DIR" ]; then
  if pgrep -xq ContextRecorder; then
    echo "Note: ContextRecorder is running; quit and reopen it to use the new build."
  fi
  rm -rf "$INSTALL_DIR/ContextRecorder.app"
  ditto "$APP" "$INSTALL_DIR/ContextRecorder.app"
  echo "Installed $INSTALL_DIR/ContextRecorder.app"
fi

#!/usr/bin/env bash
# Builds "Context Recorder.app" and signs it with a stable identity so macOS keeps
# Screen Recording / Microphone / Automation permissions across rebuilds.
# Then installs a copy to /Applications (override with INSTALL_DIR, or set
# INSTALL_DIR= to skip). If the app is running, it's quit first and reopened after.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${CODESIGN_IDENTITY:-RegionShot Local Development}"
# Launchers such as Raycast and Spotlight show the bundle file name, so it has the space.
APP_NAME="Context Recorder.app"
APP="build/$APP_NAME"
INSTALL_DIR="${INSTALL_DIR-/Applications}"

swift build -c release
rm -rf "$APP" build/ContextRecorder.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ContextRecorder "$APP/Contents/MacOS/ContextRecorder"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp scripts/process_session.py scripts/viewer.html "$APP/Contents/Resources/"

codesign --force --sign "$IDENTITY" --identifier com.byronwall.ContextRecorder "$APP"
codesign --verify --verbose=1 "$APP"
echo "Built $APP"

if [ -n "$INSTALL_DIR" ]; then
  was_running=false
  if pgrep -xq ContextRecorder; then
    was_running=true
    # Quitting mid-recording finishes the video first; give it time.
    osascript -e 'quit app id "com.byronwall.ContextRecorder"' || true
    for _ in $(seq 1 30); do pgrep -xq ContextRecorder || break; sleep 0.5; done
    if pgrep -xq ContextRecorder; then
      echo "ContextRecorder is still running; quit it and run this again." >&2
      exit 1
    fi
  fi
  # Older builds were installed as ContextRecorder.app; remove that copy too.
  rm -rf "$INSTALL_DIR/ContextRecorder.app" "$INSTALL_DIR/$APP_NAME"
  ditto "$APP" "$INSTALL_DIR/$APP_NAME"
  # Ask Launch Services/Spotlight to pick up the new name and icon right away.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_DIR/$APP_NAME" || true
  touch "$INSTALL_DIR/$APP_NAME"
  echo "Installed $INSTALL_DIR/$APP_NAME"
  if $was_running; then open "$INSTALL_DIR/$APP_NAME"; echo "Reopened it"; fi
fi

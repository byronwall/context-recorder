#!/usr/bin/env bash
# Builds "Context Recorder.app" and signs it with a stable identity so macOS keeps
# Screen Recording / Microphone / Automation permissions across rebuilds.
# Then installs a copy to /Applications (override with INSTALL_DIR, or set
# INSTALL_DIR= to skip). If the app is running, it's quit first. Launches after installing.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${CODESIGN_IDENTITY:-RegionShot Local Development}"
# Launchers such as Raycast and Spotlight show the bundle file name, so it has the space.
APP_NAME="Context Recorder.app"
APP="build/$APP_NAME"
INSTALL_DIR="${INSTALL_DIR-/Applications}"

if ! manifest_error=$(swift package dump-package 2>&1 >/dev/null); then
  case "$manifest_error" in
    *"Undefined symbols"*"PackageDescription"*)
      echo "Working around the installed Swift toolchain's PackageDescription mismatch."
      compiler="$(xcrun --find swiftc)"
      manifest_api="$(dirname "$compiler")/../lib/swift/pm/ManifestAPI"
      export CONTEXT_RECORDER_MANIFEST_CACHE="$PWD/.build/manifest-api"
      mkdir -p "$CONTEXT_RECORDER_MANIFEST_CACHE"
      "$compiler" -frontend -compile-module-from-interface \
        "$manifest_api/PackageDescription.swiftmodule/$(uname -m)-apple-macos.swiftinterface" \
        -sdk "$(xcrun --show-sdk-path)" \
        -o "$CONTEXT_RECORDER_MANIFEST_CACHE/PackageDescription.swiftmodule" \
        -module-cache-path "$CONTEXT_RECORDER_MANIFEST_CACHE"
      export SWIFT_EXEC="$PWD/scripts/swiftc.sh"
      ;;
    *)
      printf '%s\n' "$manifest_error" >&2
      exit 1
      ;;
  esac
fi

swift build -c release --product ContextRecorder
rm -rf "$APP" build/ContextRecorder.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ContextRecorder "$APP/Contents/MacOS/ContextRecorder"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp scripts/process_session.py scripts/viewer.html "$APP/Contents/Resources/"
cp -R extension "$APP/Contents/Resources/ChromeExtension"

codesign --force --sign "$IDENTITY" --identifier com.byronwall.ContextRecorder "$APP"
codesign --verify --verbose=1 "$APP"
echo "Built $APP"

if [ -n "$INSTALL_DIR" ]; then
  if pgrep -xq ContextRecorder; then
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
  open "$INSTALL_DIR/$APP_NAME"
  echo "Opened $INSTALL_DIR/$APP_NAME"
fi

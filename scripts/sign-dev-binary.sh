#!/usr/bin/env bash
# Signs the `swift build` binary (.build/debug/ContextRecorder) the way build-app.sh signs the app: same
# identity, same identifier. macOS then treats the two as the same program, so the debug binary reads the
# app's Keychain items (the cloud sign-in) without a prompt. Run it after each `swift build` that you'll use
# for `--push`.
set -euo pipefail
cd "$(dirname "$0")/.."
IDENTITY="${CODESIGN_IDENTITY:-RegionShot Local Development}"
BIN="${1:-.build/debug/ContextRecorder}"
codesign --force --sign "$IDENTITY" --identifier com.byronwall.ContextRecorder "$BIN"
APP="${APP:-/Applications/Context Recorder.app}"
if [[ -d "$APP" ]]; then
  requirement="$(codesign -d -r- "$APP" 2>&1 | sed -n 's/^designated => //p')"
  codesign --verify -R="$requirement" "$BIN" && echo "Signed $BIN; it satisfies the app's designated requirement."
fi

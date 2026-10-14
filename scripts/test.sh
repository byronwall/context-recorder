#!/usr/bin/env bash
# Runs the unit tests. With only the Command Line Tools installed, Swift Testing's framework lives outside
# the default search path, so point the compiler and linker at it.
set -euo pipefail
cd "$(dirname "$0")/.."
flags=()
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
if [[ "$(xcode-select -p)" == *CommandLineTools* && -d "$frameworks" ]]; then
  flags=(-Xswiftc "-F$frameworks" -Xlinker "-F$frameworks" -Xlinker -rpath -Xlinker "$frameworks")
fi
swift test "${flags[@]}" "$@"

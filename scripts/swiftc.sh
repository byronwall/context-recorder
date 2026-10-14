#!/usr/bin/env bash
set -euo pipefail
exec "$(xcrun --find swiftc)" -I "${CONTEXT_RECORDER_MANIFEST_CACHE:?}" "$@"
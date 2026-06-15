#!/usr/bin/env bash
# Pre-build checks for the v64 eMMC pipeline.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/tools/preflight-v64.sh"

CONFIG="$SCRIPT_DIR/config.env"
# shellcheck source=/dev/null
source "$CONFIG"

if [[ -n "${BUILD_SERVER_HOST:-}" && -n "${BUILD_SERVER_USER:-}" ]]; then
  echo ""
  echo "=== Optional remote build server ==="
  if ssh -o ConnectTimeout=10 -o BatchMode=yes \
    "$BUILD_SERVER_USER@$BUILD_SERVER_HOST" "echo SSH_OK" &>/dev/null; then
    echo "[  OK  ] SSH $BUILD_SERVER_USER@$BUILD_SERVER_HOST"
  else
    echo "[ WARN ] Cannot SSH to $BUILD_SERVER_USER@$BUILD_SERVER_HOST (local WSL build still OK)"
  fi
fi
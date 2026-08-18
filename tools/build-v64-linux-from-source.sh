#!/usr/bin/env bash
# Compatibility wrapper. Use build-from-source-linux.sh for new runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/build-from-source-linux.sh" "$@"

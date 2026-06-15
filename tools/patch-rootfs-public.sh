#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${1:?stage dir}"
DEST="$STAGE/home/m1prox1/docs"
mkdir -p "$DEST"
for f in WARNING.md UPGRADE_PATH.md GPIO_AND_HARDWARE.md BOOT_LOGO.md CONFIGURE_AND_BUILD.md SERIAL_CONSOLE.md COMPANION_SETUP.md; do
  cp "$SCRIPT_DIR/docs/$f" "$DEST/" 2>/dev/null || true
done
cp "$SCRIPT_DIR/docs/on-device/README.md" "$DEST/README.md" 2>/dev/null || true
mkdir -p "$STAGE/home/m1prox1"
echo "Staged docs for m1prox1"

#!/usr/bin/env bash
# Build rk3308bs-1.0.0-emmc-fixed-v15.img
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

echo "=== v15 release build ==="

bash "$TOOLS/build-kernel-v13-standalone.sh"
bash "$TOOLS/build-boot-v15.sh" "$REL/_Image-v15"
bash "$TOOLS/patch-rootfs-v15-debugfs.sh" "$REL/rootfs-v11.img" "$REL/rootfs-v15.img"
bash "$TOOLS/stage-pack-v15.sh" "$REL/rootfs-v15.img"

WIN_SCRIPT="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
WIN_PACK="$(wslpath -w "$REL/pack_input_v15")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" \
  -PackInput "$WIN_PACK" \
  -Output "rk3308bs-1.0.0-emmc-fixed-v15.img"

cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v15.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v15.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
echo "DONE: flash $REL/rk3308bs-1.0.0-emmc-fixed-v15.img (Upgrade Firmware tab)"

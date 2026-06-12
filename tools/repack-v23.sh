#!/usr/bin/env bash
# Repack rootfs + flash image only (no kernel rebuild).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

export RK3308BS_IMAGE_TAG="v24-wifi-grow"
bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$REL/rootfs-v11.img" "$REL/rootfs-v24-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-wifi.sh" \
  "$REL/rootfs-v24-patched.img" \
  "$REL/rootfs-v24.img"
bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v24.img"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/windows-pack-update.ps1" \
  -PackInput "$REL/pack_input_v16" \
  -Output "rk3308bs-1.0.0-emmc-fixed-v24.img"

cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v24.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v24.img"

#!/usr/bin/env bash
# v16: stable boot (v13-sized kernel) + PRESET rootfs + optional DRM modules.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

echo "=== v16 stable release build ==="

bash "$TOOLS/build-kernel-v16-stable.sh"
bash "$TOOLS/build-boot-v16.sh"
bash "$TOOLS/patch-rootfs-v15-debugfs.sh" "$REL/rootfs-v11.img" "$REL/rootfs-v15.img"

ROOTFS="$REL/rootfs-v16.img"
if bash "$TOOLS/install-kernel-modules-to-rootfs.sh" "$REL/rootfs-v15.img" "$ROOTFS" 2>/dev/null; then
  echo "Installed matching 6.18.0-dirty kernel modules for LCD"
else
  echo "WARN: no sudo  -  using rootfs without kernel modules (serial OK, LCD may stay blank)"
  cp "$REL/rootfs-v15.img" "$ROOTFS"
fi

bash "$TOOLS/stage-pack-v16.sh" "$ROOTFS"

WIN_SCRIPT="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" \
  -PackInput "$WIN_PACK" \
  -Output "rk3308bs-1.0.0-emmc-fixed-v16.img"

cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v16.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v16.img"
echo "DONE: flash $REL/rk3308bs-1.0.0-emmc-fixed-v16.img"

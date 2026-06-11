#!/usr/bin/env bash
# Build rk3308bs-1.0.0-emmc-fixed-v14.img (reboot-safe rootfs + LCD kernel + TSADC).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

echo "=== v14 release build ==="

if [[ ! -f "$REL/_Image-v14" ]]; then
  bash "$TOOLS/build-kernel-v13-standalone.sh"
fi
if [[ ! -f "$REL/_boot-v14.img" ]]; then
  bash "$TOOLS/build-boot-v14.sh"
fi

bash "$TOOLS/patch-rootfs-v14-debugfs.sh" "$REL/rootfs-v11.img" "$REL/rootfs-v14.img"
bash "$TOOLS/stage-pack-v14.sh" "$REL/rootfs-v14.img"

WIN_SCRIPT="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
WIN_PACK="$(wslpath -w "$REL/pack_input_v14")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" \
  -PackInput "$WIN_PACK" \
  -Output "rk3308bs-1.0.0-emmc-fixed-v14.img"

cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v14.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v14.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
echo "DONE: flash $REL/rk3308bs-1.0.0-emmc-fixed-v14.img (Upgrade Firmware tab)"

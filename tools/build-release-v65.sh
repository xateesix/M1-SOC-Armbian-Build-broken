#!/usr/bin/env bash
# v65: post-factory-test image ? v64 base + MOTD A3D fix + depmod + audit tools.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

[[ -f "$REL/_Image-v22" ]] || { echo "Missing _Image-v22"; exit 1; }
[[ -f "$REL/rootfs-v61.img" ]] || { echo "Missing rootfs-v61.img"; exit 1; }

bash "$TOOLS/build-boot-v65.sh" "$REL/_Image-v22"
bash "$TOOLS/patch-rootfs-v65-debugfs.sh" "$REL/rootfs-v61.img" "$REL/rootfs-v65.img"
bash "$TOOLS/stage-pack-v65.sh"
WIN_PACK="$(wslpath -w "$REL/pack_input_v65")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v65.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v65.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v65.img"

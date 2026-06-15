#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
ROOTFS="${1:-$REL/rootfs-v45.img}"
[[ -f "$ROOTFS" ]] || { echo "Missing rootfs"; exit 1; }
[[ -f "$REL/_Image-v22" ]] || { echo "Missing $REL/_Image-v22"; exit 1; }

bash "$TOOLS/build-boot-v49.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v49.sh" "$ROOTFS"
bash "$TOOLS/verify-pack-parameter.sh" "$REL/pack_input_v49/Image/parameter.txt"
WIN_PACK="$(wslpath -w "$REL/pack_input_v49")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v49.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v49.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v49.img"
echo ""
echo "=== FLASH v49 debug boot ==="
echo "Upgrade Firmware tab -> $REL/rk3308bs-1.0.0-emmc-fixed-v49.img"
echo "Log MUST show: total=1677655552 and rootfs ~47-51s"
echo "Serial: capture log after clk disable - initcall_debug shows last initcall before hang"

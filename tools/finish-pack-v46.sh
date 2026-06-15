#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
ROOTFS="${1:-$REL/rootfs-v46.img}"
[[ -f "$ROOTFS" ]] || ROOTFS="$REL/rootfs-v45.img"
[[ -f "$ROOTFS" ]] || { echo "Missing rootfs"; exit 1; }
[[ -f "$REL/_boot-v39.img" ]] || bash "$TOOLS/build-boot-v39.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v39.sh" "$ROOTFS"
bash "$TOOLS/verify-pack-parameter.sh" "$REL/pack_input_v39/Image/parameter.txt"
WIN_PACK="$(wslpath -w "$REL/pack_input_v39")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v46.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v46.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v46.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v46.img"
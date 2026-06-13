#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
bash "$SCRIPT_DIR/tools/stage-pack-v39.sh" "$REL/rootfs-v45.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v39")"
WIN_PS="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS" \
	-PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v45.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v45.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v45.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v45.img"

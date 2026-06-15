#!/usr/bin/env bash
# v64: v61 display + pwm0-pin lightbar + SD slot + test tools + Armbian MOTD.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

[[ -f "$REL/_Image-v22" ]] || { echo "Missing _Image-v22"; exit 1; }
[[ -f "$REL/rootfs-v61.img" ]] || { echo "Missing rootfs-v61.img"; exit 1; }

bash "$TOOLS/build-boot-v64.sh" "$REL/_Image-v22"
bash "$TOOLS/patch-rootfs-v64-debugfs.sh" "$REL/rootfs-v61.img" "$REL/rootfs-v64.img"
bash "$TOOLS/stage-pack-v64.sh"
WIN_PACK="$(wslpath -w "$REL/pack_input_v64")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v64.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v64.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v64.img"

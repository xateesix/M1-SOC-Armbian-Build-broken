#!/usr/bin/env bash
# v62: v61 display path + PWM0 lightbar DTB + LED test tools.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

[[ -f "$REL/_Image-v22" ]] || { echo "Missing _Image-v22"; exit 1; }
[[ -f "$REL/rootfs-v61.img" ]] || { echo "Missing rootfs-v61.img"; exit 1; }

bash "$TOOLS/build-boot-v62.sh" "$REL/_Image-v22"
bash "$TOOLS/patch-rootfs-v62-lights.sh" "$REL/rootfs-v61.img" "$REL/rootfs-v62.img"
bash "$TOOLS/stage-pack-v62.sh"
WIN_PACK="$(wslpath -w "$REL/pack_input_v62")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v62.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v62.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v62.img"

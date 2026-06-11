#!/usr/bin/env bash
# v17: v16 stable kernel/boot + rootfs with baked credentials (login works on serial).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"

echo "=== v17 release (v16 kernel + baked credentials) ==="

[[ -f "$REL/_Image-v16" ]] || bash "$TOOLS/build-kernel-v16-stable.sh"
[[ -f "$REL/_boot-v16.img" ]] || bash "$TOOLS/build-boot-v16.sh"

bash "$TOOLS/patch-rootfs-v17-debugfs.sh" "$REL/rootfs-v11.img" "$REL/rootfs-v17.img"

bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v17.img"

WIN_SCRIPT="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" \
  -PackInput "$WIN_PACK" \
  -Output "rk3308bs-1.0.0-emmc-fixed-v17.img"

cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v17.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v17.img"
echo "DONE: flash $REL/rk3308bs-1.0.0-emmc-fixed-v17.img"
echo "Login: root or ${USER_NAME:-xateesix} / password from config.env"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
CONFIG="$SCRIPT_DIR/config.env"

# shellcheck source=/dev/null
source "$CONFIG"

echo "=== v21 release (official Armbian firstrun preset  -  no debugfs passwd edits) ==="

[[ -f "$REL/_Image-v16" ]] || bash "$TOOLS/build-kernel-v16-stable.sh"
[[ -f "$REL/_boot-v16.img" ]] || bash "$TOOLS/build-boot-v16.sh"

export RK3308BS_IMAGE_TAG="v21-armbian-firstrun"
bash "$TOOLS/patch-rootfs-v21-firstrun.sh" "$REL/rootfs-v11.img" "$REL/rootfs-v21.img"

bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v21.img"

WIN_SCRIPT="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" \
  -PackInput "$WIN_PACK" \
  -Output "rk3308bs-1.0.0-emmc-fixed-v21.img"

cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v21.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v21.img"
echo "DONE: flash $REL/rk3308bs-1.0.0-emmc-fixed-v21.img"
echo "First boot: root shell on serial  ->  Armbian firstrun runs  ->  then use ${USER_NAME} / ${USER_PASSWORD}"
echo "Verify: cat /etc/rk3308bs-release  (expect v21-armbian-firstrun)"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
CONFIG="$SCRIPT_DIR/config.env"

# shellcheck source=/dev/null
source "$CONFIG"

echo "=== v22 release (WiFi OutIOT + 8189fs + eMMC rootfs grow) ==="

bash "$TOOLS/build-kernel-v22-wifi.sh"
bash "$TOOLS/build-boot-v16.sh" "$REL/_Image-v22"

export RK3308BS_IMAGE_TAG="v22-wifi-grow"
bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$REL/rootfs-v11.img" "$REL/rootfs-v22-patched.img"

bash "$TOOLS/install-kernel-modules-debugfs-wifi.sh" \
  "$REL/rootfs-v22-patched.img" \
  "$REL/rootfs-v22.img"

bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v22.img"

WIN_SCRIPT="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" \
  -PackInput "$WIN_PACK" \
  -Output "rk3308bs-1.0.0-emmc-fixed-v22.img"

cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v22.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v22.img"
echo "DONE: flash $REL/rk3308bs-1.0.0-emmc-fixed-v22.img"
echo "First boot: firstrun + WiFi ${WIFI_SSID} + rootfs grow to ~6GB"
echo "Verify: cat /etc/rk3308bs-release  (expect v22-wifi-grow)"

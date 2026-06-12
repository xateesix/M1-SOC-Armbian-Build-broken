#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
CONFIG="$SCRIPT_DIR/config.env"
BUILD_DIR="/tmp/rk3308bs-v25-build"
source "$CONFIG"
echo "=== v25 monolithic release (WiFi + LCD + grow) ==="
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
[[ -f "$REL/rootfs-v11.img" ]] || exit 1
[[ -f "$REL/_Image-v22" ]] || bash "$TOOLS/build-kernel-v22-wifi.sh"
bash "$TOOLS/build-boot-v16.sh" "$REL/_Image-v22"
export RK3308BS_IMAGE_TAG="v25-wifi-display-grow"
bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v25.img"
cp -f "$BUILD_DIR/rootfs-v25.img" "$REL/rootfs-v25.img"
bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v25.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v25.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v25.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v25.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v25.img"

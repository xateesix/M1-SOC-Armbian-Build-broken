#!/usr/bin/env bash
# v38: v37 rootfs + kernel with rk3308-rgb platform driver + panel timing fallback.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v38"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v38-wifi-display-grow"

python3 "$TOOLS/gen-panel-simple-patch.py"
bash "$TOOLS/build-kernel-v22-wifi.sh"
cp ~/linux-v13-build/.config "$REL/_config-v38.txt"
grep -q '^CONFIG_ROCKCHIP_RGB=y' "$REL/_config-v38.txt"
grep -q 'rockchip_rgb_platform_driver' ~/linux-v13-build/drivers/gpu/drm/rockchip/rockchip_rgb.c
bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v38.img"
cp -f "$BUILD_DIR/rootfs-v38.img" "$REL/rootfs-v38.img"
bash "$TOOLS/build-boot-v16.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v38.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v38.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v38.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v38.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v38.img"

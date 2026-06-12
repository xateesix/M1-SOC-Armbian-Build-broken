#!/usr/bin/env bash
# v36: v34 stable kernel + panel-simple/pwm_bl built-in (factory bind order), rockchipdrm module.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v36"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v36-wifi-display-grow"

python3 "$TOOLS/gen-panel-simple-patch.py"
bash "$TOOLS/build-kernel-v22-wifi.sh"
cp ~/linux-v13-build/.config "$REL/_config-v36.txt"
grep -q '^CONFIG_DRM_PANEL_SIMPLE=y' "$REL/_config-v36.txt"
grep -q '^CONFIG_BACKLIGHT_PWM=y' "$REL/_config-v36.txt"
grep -q '^CONFIG_DRM_ROCKCHIP=m' "$REL/_config-v36.txt"
bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v36.img"
cp -f "$BUILD_DIR/rootfs-v36.img" "$REL/rootfs-v36.img"
bash "$TOOLS/build-boot-v16.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v36.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v36.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v36.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v36.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v36.img"

#!/usr/bin/env bash
# v41: v40 + fix optional power regulator -ENODEV (panel had no power supply in DT).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v41"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v41-wifi-display-grow"

python3 "$TOOLS/gen-panel-simple-patch.py"
bash "$TOOLS/gen-patch-0007.sh"
bash "$TOOLS/build-kernel-v22-wifi.sh"
grep -q 'PTR_ERR(panel->supply) == -ENODEV' ~/linux-v13-build/drivers/gpu/drm/panel/panel-simple.c
bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v41.img"
cp -f "$BUILD_DIR/rootfs-v41.img" "$REL/rootfs-v41.img"
bash "$TOOLS/build-boot-v39.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v39.sh" "$REL/rootfs-v41.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v39")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v41.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v41.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v41.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v41.img"

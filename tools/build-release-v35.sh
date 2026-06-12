#!/usr/bin/env bash
# v35: v34 stable kernel + improved LCD module load / deferred-probe logging.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v35"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v35-wifi-display-grow"

bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v35.img"
cp -f "$BUILD_DIR/rootfs-v35.img" "$REL/rootfs-v35.img"
bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v35.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v35.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v35.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v35.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v35.img"

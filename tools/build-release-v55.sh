#!/usr/bin/env bash
# v55 release: growfix + expand + chroot display modules + v53 boot pack.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v55"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v55-expanded-display"

[[ -f "$REL/rootfs-v11.img" ]] || { echo "Missing rootfs-v11.img"; exit 1; }
[[ -f "$REL/_Image-v22" ]] || { echo "Missing kernel Image"; exit 1; }

bash "$TOOLS/patch-rootfs-v45-mount.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/patch-rootfs-v54-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v54.img"
bash "$TOOLS/patch-rootfs-v55-growfix.sh" "$BUILD_DIR/rootfs-v54.img" "$BUILD_DIR/rootfs-growfix.img"
bash "$TOOLS/patch-rootfs-v55-expand.sh" "$BUILD_DIR/rootfs-growfix.img" "$BUILD_DIR/rootfs-expanded.img"
bash "$TOOLS/install-kernel-modules-chroot-display.sh" "$BUILD_DIR/rootfs-expanded.img" "$BUILD_DIR/rootfs-v55.img"
cp -f "$BUILD_DIR/rootfs-v55.img" "$REL/rootfs-v55.img"

bash "$TOOLS/build-boot-v53.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v54.sh" "$REL/rootfs-v55.img"
bash "$TOOLS/verify-pack-parameter.sh" "$REL/pack_input_v54/Image/parameter.txt"
WIN_PACK="$(wslpath -w "$REL/pack_input_v54")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v55.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v55.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v55.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v55.img"

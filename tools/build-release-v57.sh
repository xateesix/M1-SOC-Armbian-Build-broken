#!/usr/bin/env bash
# v57 release: v55 rootfs + display fixes + v57 boot (tty0 fbcon + de-active=0 + logo).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v57"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v57-display-console"

[[ -f "$REL/rootfs-v11.img" ]] || { echo "Missing rootfs-v11.img"; exit 1; }
[[ -f "$REL/_Image-v22" ]] || { echo "Missing kernel Image"; exit 1; }

bash "$TOOLS/patch-rootfs-v45-mount.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/patch-rootfs-v54-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v54.img"
bash "$TOOLS/patch-rootfs-v55-growfix.sh" "$BUILD_DIR/rootfs-v54.img" "$BUILD_DIR/rootfs-growfix.img"
bash "$TOOLS/patch-rootfs-v55-expand.sh" "$BUILD_DIR/rootfs-growfix.img" "$BUILD_DIR/rootfs-expanded.img"
bash "$TOOLS/install-kernel-modules-chroot-display.sh" "$BUILD_DIR/rootfs-expanded.img" "$BUILD_DIR/rootfs-v57.img"
cp -f "$BUILD_DIR/rootfs-v57.img" "$REL/rootfs-v57.img"

bash "$TOOLS/build-boot-v57.sh" "$REL/_Image-v22"

PACK="$REL/pack_input_v57"
FAC="$SCRIPT_DIR/factory_fresh/03_partitions"
rm -rf "$PACK"
mkdir -p "$PACK/Image"
cp "$FAC/package-file" "$PACK/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$PACK/Image/"
cp "$REL/_uboot-memlayout.img" "$PACK/Image/uboot.img"
cp "$REL/_boot-v57.img" "$PACK/Image/boot.img"
cp "$REL/rootfs-v57.img" "$PACK/Image/rootfs.img"
python3 "$TOOLS/patch-parameter-boot-size.py" \
  "$FAC/parameter.txt" "$PACK/Image/boot.img" "$PACK/Image/parameter.txt" \
  --rootfs "$PACK/Image/rootfs.img"
bash "$TOOLS/verify-pack-parameter.sh" "$PACK/Image/parameter.txt"

WIN_PACK="$(wslpath -w "$PACK")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v57.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v57.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v57.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v57.img"

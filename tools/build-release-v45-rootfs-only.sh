#!/usr/bin/env bash
# v45: v43 kernel + hybrid chroot/system.cfg rootfs (no debugfs inode corruption).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v45"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v45-systemcfg-chroot"

[[ -f "$REL/_Image-v22" ]] || { echo "Missing kernel Image  -  run build-release-v43.sh first"; exit 1; }

bash "$TOOLS/patch-rootfs-v45-mount.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v45.img"
cp -f "$BUILD_DIR/rootfs-v45.img" "$REL/rootfs-v45.img"
bash "$TOOLS/build-boot-v39.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v39.sh" "$REL/rootfs-v45.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v39")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v45.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v45.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v45.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v45.img"
echo "Flash via RKDevTool (full upgrade). After boot: cat /etc/rk3308bs-release; lsblk; dmesg | grep mmc"

#!/usr/bin/env bash
# v29: v28 rootfs + boot DTB with VOP CRU resets (fixes "failed to get ahb reset").
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v29"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v29-wifi-display-grow"

[[ -f "$REL/rootfs-v28.img" ]] || { echo "Missing $REL/rootfs-v28.img — run pack-release-v28-only.sh first"; exit 1; }

# Re-tag release file on a copy of v28 rootfs
cp -f "$REL/rootfs-v28.img" "$BUILD_DIR/rootfs-v29.img"
RELEASE_TXT="$BUILD_DIR/rk3308bs-release"
cat >"$RELEASE_TXT" <<EOF
RK3308BS_IMAGE=${RK3308BS_IMAGE_TAG}
RK3308BS_USER=xateesix
RK3308BS_WIFI=OurIOT
RK3308BS_ROOTFS_GROW=oneshot
RK3308BS_LCD=480x272-rgb
EOF
debugfs -w -R "rm /etc/rk3308bs-release" "$BUILD_DIR/rootfs-v29.img" 2>/dev/null || true
debugfs -w -R "write $RELEASE_TXT /etc/rk3308bs-release" "$BUILD_DIR/rootfs-v29.img"
debugfs -w -R "rm /etc/hostname" "$BUILD_DIR/rootfs-v29.img" 2>/dev/null || true
echo "rk3308bs-${RK3308BS_IMAGE_TAG}" >"$BUILD_DIR/hostname"
debugfs -w -R "write $BUILD_DIR/hostname /etc/hostname" "$BUILD_DIR/rootfs-v29.img"
cp -f "$BUILD_DIR/rootfs-v29.img" "$REL/rootfs-v29.img"

bash "$TOOLS/build-boot-v16.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v16.sh" "$REL/rootfs-v29.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v16")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v29.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v29.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v29.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v29.img"

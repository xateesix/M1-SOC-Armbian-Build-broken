#!/usr/bin/env bash
# Repack v43 rootfs/boot only (reuse existing v43 kernel with patch 0008).
# WARNING: uses patch-rootfs-v17-debugfs.sh — corrupts ext4 inodes (bogus i_mode login loop).
# Do NOT flash for new installs. Use build-release-v45-rootfs-only.sh instead.
set -euo pipefail
echo "WARNING: v43 rootfs patch uses debugfs set_inode_field (known corrupt). Prefer v45." >&2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v43"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v43-wifi-display-grow"

[[ -f "$REL/_Image-v22" ]] || { echo "Missing kernel Image — run build-release-v43.sh first"; exit 1; }

bash "$TOOLS/patch-rootfs-v17-debugfs.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-v17.img"
bash "$TOOLS/patch-rootfs-v22-wifi.sh" "$BUILD_DIR/rootfs-v17.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v43.img"
cp -f "$BUILD_DIR/rootfs-v43.img" "$REL/rootfs-v43.img"
bash "$TOOLS/build-boot-v39.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v39.sh" "$REL/rootfs-v43.img"
WIN_PACK="$(wslpath -w "$REL/pack_input_v39")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v43.img"
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v43.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v43.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v43.img"

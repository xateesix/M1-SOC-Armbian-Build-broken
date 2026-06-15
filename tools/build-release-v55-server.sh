#!/usr/bin/env bash
# v55 release (server): growfix + expand + chroot display modules + v53 boot pack.
# No Windows powershell pack step.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v55"
TMPDIR="$SCRIPT_DIR/.build-v55/tmp"
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

bash "$TOOLS/notify-discord.sh" "M1-SOC v55: SERVER_BUILD_DONE on $(hostname)"

ls -la "$REL/rootfs-v55.img" "$REL/pack_input_v54/Image/rootfs.img" "$REL/_boot-v53.img" 2>/dev/null || true
echo "DONE rootfs: $REL/rootfs-v55.img"
echo "DONE pack rootfs: $REL/pack_input_v54/Image/rootfs.img"
echo "DONE boot: $REL/_boot-v53.img"
echo "DONE pack dir: $REL/pack_input_v54"
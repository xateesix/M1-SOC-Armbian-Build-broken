#!/usr/bin/env bash
# v55 release: growfix + expand + chroot display modules + v53 boot pack.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="${RELEASE_DIR:-../pack/releases/1.0.0}"
REL="${REL:-$SCRIPT_DIR/$RELEASE_DIR}"
TOOLS="${TOOLS:-$SCRIPT_DIR/tools}"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/.build-v55}"
TMPDIR="${TMPDIR:-$SCRIPT_DIR/.wsl-tmp}"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="${RK3308BS_IMAGE_TAG:-v55-expanded-display}"
PACK_SUBDIR="${PACK_SUBDIR:-pack_input}"
OUT_IMAGE="${OUT_IMAGE:-rk3308bs-emmc-fixed.img}"
COPY_IMAGE="${COPY_IMAGE:-rk3308bs-emmc-fixed-copy.img}"
WINDOWS_SCRIPT="${WINDOWS_SCRIPT:-$SCRIPT_DIR/windows-pack-update.ps1}"

[[ -f "$REL/rootfs-v11.img" ]] || { echo "Missing rootfs-v11.img"; exit 1; }
[[ -f "$REL/_Image-v22" ]] || { echo "Missing kernel Image"; exit 1; }

bash "$TOOLS/patch-rootfs-v45-mount.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/patch-rootfs-v54-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v54.img"
bash "$TOOLS/patch-rootfs-v55-growfix.sh" "$BUILD_DIR/rootfs-v54.img" "$BUILD_DIR/rootfs-growfix.img"
bash "$TOOLS/patch-rootfs-v55-expand.sh" "$BUILD_DIR/rootfs-growfix.img" "$BUILD_DIR/rootfs-expanded.img"
bash "$TOOLS/install-kernel-modules-chroot-display.sh" "$BUILD_DIR/rootfs-expanded.img" "$BUILD_DIR/rootfs-v55.img"
cp -f "$BUILD_DIR/rootfs-v55.img" "$REL/rootfs-v55.img"

bash "$BOOT_SCRIPT" "$REL/_Image-v22"
bash "$STAGE_SCRIPT" "$REL/rootfs-v55.img"
bash "$VERIFY_SCRIPT" "$REL/$PACK_SUBDIR/Image/parameter.txt"
WIN_PACK="$(wslpath -w "$REL/$PACK_SUBDIR")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$WINDOWS_SCRIPT")" \
  -PackInput "$WIN_PACK" -Output "$OUT_IMAGE"
cp -f "$REL/$OUT_IMAGE" "$REL/$COPY_IMAGE"
ls -la "$REL/$OUT_IMAGE"
echo "DONE: $REL/$OUT_IMAGE"

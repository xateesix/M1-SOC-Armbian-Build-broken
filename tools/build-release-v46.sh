#!/usr/bin/env bash
# v46: v45 rootfs + factory rootfs:grow GPT (fixes mount panic on unnamed partition).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v46"
TMPDIR="$SCRIPT_DIR/.wsl-tmp"
export TMPDIR
mkdir -p "$TMPDIR" "$BUILD_DIR"
export RK3308BS_IMAGE_TAG="v46-grow-gpt"

[[ -f "$REL/_Image-v22" ]] || { echo "Missing kernel Image"; exit 1; }
[[ -f "$REL/rootfs-v11.img" ]] || { echo "Missing rootfs-v11.img"; exit 1; }

bash "$TOOLS/patch-rootfs-v45-mount.sh" "$REL/rootfs-v11.img" "$BUILD_DIR/rootfs-patched.img"
bash "$TOOLS/install-kernel-modules-debugfs-all.sh" "$BUILD_DIR/rootfs-patched.img" "$BUILD_DIR/rootfs-v46.img"
cp -f "$BUILD_DIR/rootfs-v46.img" "$REL/rootfs-v46.img"
bash "$TOOLS/build-boot-v39.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v39.sh" "$REL/rootfs-v46.img"
bash "$TOOLS/verify-pack-parameter.sh" "$REL/pack_input_v39/Image/parameter.txt"
WIN_PACK="$(wslpath -w "$REL/pack_input_v39")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v46.img"
strings "$REL/rk3308bs-1.0.0-emmc-fixed-v46.img" | grep -E "rootfs:grow|uuid:rootfs" | head -3
cp -f "$REL/rk3308bs-1.0.0-emmc-fixed-v46.img" "$REL/rk3308bs-1.0.0-emmc-fixed.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v46.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v46.img"
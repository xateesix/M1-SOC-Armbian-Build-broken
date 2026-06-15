#!/usr/bin/env bash
# Install patches + board config, rebuild Armbian kernel for rk3308bs-evb (current / 6.18).
# Falls back to standalone cross-compile when Docker/sudo is unavailable.
set -euo pipefail
REPO="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian"
AB="$HOME/armbian-build"
REL="$REPO/releases/1.0.0"
TOOLS="$REPO/tools"

if [ ! -d "$AB" ]; then
  echo "Missing ~/armbian-build  -  clone https://github.com/armbian/build first"
  exit 1
fi

mkdir -p "$AB/config/boards" "$AB/userpatches/kernel/rockchip64-current"
cp "$REPO/rk3308bs-evb.conf" "$AB/config/boards/rk3308bs-evb.conf"
cp "$REPO/patches/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch" \
  "$AB/userpatches/kernel/rockchip64-current/0001-add-rk3308bs-evb.patch"
cp "$REPO/patches/0002-thermal-rockchip-rk3308bs-tsadc.patch" \
  "$AB/userpatches/kernel/rockchip64-current/0002-rk3308bs-tsadc.patch"
cp "$REPO/patches/0002-thermal-rockchip-rk3308bs-tsadc.patch" \
  "$AB/patch/kernel/archive/rockchip64-6.18/rk3308bs-tsadc-linear.patch"

if command -v docker >/dev/null 2>&1 || sudo -n true 2>/dev/null; then
  echo "=== Building kernel via Armbian (BOARD=rk3308bs-evb BRANCH=current) ==="
  cd "$AB"
  ./compile.sh kernel BOARD=rk3308bs-evb BRANCH=current
  IMG=$(find "$AB/.cache" -path '*/linux-image-current-rockchip64_*/boot/Image' 2>/dev/null | head -1)
  if [ -z "$IMG" ]; then
    IMG=$(find "$AB/.cache" -name Image -path '*/image_*/*' 2>/dev/null | head -1)
  fi
else
  echo "=== Docker/sudo unavailable  -  standalone cross-compile ==="
  bash "$TOOLS/build-kernel-v13-standalone.sh"
  exit 0
fi

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  echo "Could not find built Image under $AB/.cache"
  exit 1
fi
cp "$IMG" "$REL/_Image-v13"
ls -la "$REL/_Image-v13"
file "$REL/_Image-v13"

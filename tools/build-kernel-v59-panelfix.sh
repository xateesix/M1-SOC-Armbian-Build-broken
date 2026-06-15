#!/usr/bin/env bash
# Rebuild kernel Image with panel-enable fix (patch 0009 in-tree).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$SCRIPT_DIR"
REL="$REPO/releases/1.0.0"
SRC="${KERNEL_SRC:-$HOME/linux-v13-build}"
AB="${ARMBIAN_BUILD:-$HOME/armbian-build}"
JOBS="$(nproc)"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

[[ -d "$SRC/.git" ]] || { echo "Missing kernel src: $SRC"; exit 1; }

cd "$SRC"
git checkout -f v6.18
for p in 0002 0003 0004 0005 0006 0007 0008; do
  patch -p1 --forward < "$REPO/patches/${p}-"*.patch || true
done
python3 "$REPO/tools/patch-panel-enable-in-tree.py" "$SRC/drivers/gpu/drm/panel/panel-simple.c"

bash "$REPO/tools/integrate-rtl8189fs.sh" "$SRC" "$AB" 2>/dev/null || true
cp "$AB/config/kernel/linux-rockchip64-current.config" .config
"$SRC/scripts/kconfig/merge_config.sh" -m .config \
  "$REPO/config/rk3308bs-stable.fragment" \
  "$REPO/config/rk3308bs-modules.fragment" \
  "$REPO/config/rk3308bs-wifi.fragment"
make olddefconfig
make Image -j"$JOBS"
cp arch/arm64/boot/Image "$REL/_Image-v59"
echo "Kernel Image: $REL/_Image-v59"

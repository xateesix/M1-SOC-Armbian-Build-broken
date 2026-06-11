#!/usr/bin/env bash
# Cross-compile Linux 6.18 with rk3308 TSADC + RK3308BS linear thermal fix (no Docker/sudo).
set -euo pipefail
REPO="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian"
AB="$HOME/armbian-build"
REL="$REPO/releases/1.0.0"
SRC="$HOME/linux-v13-build"
JOBS="$(nproc)"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

if ! command -v "${CROSS_COMPILE}gcc" >/dev/null; then
  echo "Install: sudo apt-get install -y gcc-aarch64-linux-gnu bc bison flex libssl-dev libncurses-dev"
  exit 1
fi

if [ ! -d "$AB/patch/kernel/archive/rockchip64-6.18" ]; then
  echo "Missing $AB/patch/kernel/archive/rockchip64-6.18"
  exit 1
fi

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 --branch v6.18 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$SRC"
fi

cd "$SRC"
git fetch --depth 1 origin tag v6.18 2>/dev/null || true
git checkout -f v6.18

echo "=== Apply Armbian rk3308 TSADC patch ==="
patch -p1 --forward < "$AB/patch/kernel/archive/rockchip64-6.18/rk3308-add-tsadc-driver.patch"

echo "=== Apply RK3308BS linear TSADC patch ==="
patch -p1 --forward < "$REPO/patches/0002-thermal-rockchip-rk3308bs-tsadc.patch"

echo "=== Configure (Armbian rockchip64-current + RK3308BS display) ==="
cp "$AB/config/kernel/linux-rockchip64-current.config" .config
"$SRC/scripts/kconfig/merge_config.sh" -m .config \
  "$REPO/config/rk3308bs-display.fragment" \
  "$REPO/config/rk3308bs-stable.fragment"
make olddefconfig
make Image -j"$JOBS"

cp arch/arm64/boot/Image "$REL/_Image-v15"
cp arch/arm64/boot/Image "$REL/_Image-v14"
ls -la "$REL/_Image-v15"
file "$REL/_Image-v15"
# Verify built-in DRM (not modules)
if ! "${CROSS_COMPILE}nm" -n arch/arm64/boot/vmlinux 2>/dev/null | grep -q ' rockchip_drm'; then
  if ! strings arch/arm64/boot/Image | grep -q rockchip_drm; then
    echo "WARN: rockchip_drm symbol not found in Image"
  fi
fi
echo "KERNEL_V15_OK"

#!/usr/bin/env bash
# v22 kernel: v16 stable + rtl8189fs WiFi driver.
set -euo pipefail
REPO="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian"
AB="$HOME/armbian-build"
REL="$REPO/releases/1.0.0"
SRC="$HOME/linux-v13-build"
JOBS="$(nproc)"
TOOLS="$REPO/tools"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

cd "$SRC"
git checkout -f v6.18
patch -p1 --forward < "$AB/patch/kernel/archive/rockchip64-6.18/rk3308-add-tsadc-driver.patch"
patch -p1 --forward < "$REPO/patches/0002-thermal-rockchip-rk3308bs-tsadc.patch"
patch -p1 --forward < "$REPO/patches/0003-drm-rockchip-rk3308-vop-driver.patch"
patch -p1 --forward < "$REPO/patches/0004-panel-simple-simple-panel-compat.patch"
patch -p1 --forward < "$REPO/patches/0005-rk3308-rgb-platform-driver.patch"

bash "$TOOLS/integrate-rtl8189fs.sh" "$SRC" "$AB"

cp "$AB/config/kernel/linux-rockchip64-current.config" .config
"$SRC/scripts/kconfig/merge_config.sh" -m .config \
  "$REPO/config/rk3308bs-stable.fragment" \
  "$REPO/config/rk3308bs-modules.fragment" \
  "$REPO/config/rk3308bs-wifi.fragment"
make olddefconfig
make Image modules -j"$JOBS"

KVER="$(make -s kernelrelease)"
STAGE="$REL/_modules_${KVER}"
rm -rf "$STAGE"
make INSTALL_MOD_PATH="$STAGE" modules_install

cp arch/arm64/boot/Image "$REL/_Image-v22"
cp arch/arm64/boot/Image "$REL/_Image-v16"
ls -la "$REL/_Image-v22"
echo "KERNEL_V22_OK kver=$KVER modules=$STAGE"
# Verify 8189fs built
find "$STAGE" -name '8189fs.ko' -o -name '8189fs.ko.xz' 2>/dev/null | head -3

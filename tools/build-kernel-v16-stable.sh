#!/usr/bin/env bash
# v16 stable kernel: TSADC only — NO built-in DRM (avoids __run_timers panic).
set -euo pipefail
REPO="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian"
AB="$HOME/armbian-build"
REL="$REPO/releases/1.0.0"
SRC="$HOME/linux-v13-build"
JOBS="$(nproc)"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

cd "$SRC"
git checkout -f v6.18
patch -p1 --forward < "$AB/patch/kernel/archive/rockchip64-6.18/rk3308-add-tsadc-driver.patch"
patch -p1 --forward < "$REPO/patches/0002-thermal-rockchip-rk3308bs-tsadc.patch"
patch -p1 --forward < "$REPO/patches/0003-drm-rockchip-rk3308-vop-driver.patch"
patch -p1 --forward < "$REPO/patches/0004-panel-simple-simple-panel-compat.patch"

cp "$AB/config/kernel/linux-rockchip64-current.config" .config
"$SRC/scripts/kconfig/merge_config.sh" -m .config \
  "$REPO/config/rk3308bs-stable.fragment" \
  "$REPO/config/rk3308bs-modules.fragment"
make olddefconfig
make Image modules -j"$JOBS"

KVER="$(make -s kernelrelease)"
STAGE="$REL/_modules_${KVER}"
rm -rf "$STAGE"
make INSTALL_MOD_PATH="$STAGE" modules_install

cp arch/arm64/boot/Image "$REL/_Image-v16"
ls -la "$REL/_Image-v16"
echo "KERNEL_V16_OK modules=$STAGE"

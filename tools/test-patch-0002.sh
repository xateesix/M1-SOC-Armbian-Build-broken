#!/usr/bin/env bash
# Verify 0002 patch applies on top of Armbian 6.18 rk3308 tsadc patch.
set -euo pipefail
AB="$HOME/armbian-build"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 --branch v6.18 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$TMP/linux" 2>/dev/null || \
  git clone --depth 1 --branch linux-6.18.y https://github.com/gregkh/linux.git "$TMP/linux"

cd "$TMP/linux"
patch -p1 --forward < "$AB/patch/kernel/archive/rockchip64-6.18/rk3308-add-tsadc-driver.patch"
patch -p1 --forward < "/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/patches/0002-thermal-rockchip-rk3308bs-tsadc.patch"
grep -n 'rk3308bs_tsadc_data\|kNum' drivers/thermal/rockchip_thermal.c | head -10
echo "PATCH_OK"

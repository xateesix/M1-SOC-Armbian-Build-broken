#!/usr/bin/env bash
set -euo pipefail
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone --depth 1 --branch v6.18 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$TMP/linux"
cd "$TMP/linux"
patch -p1 --forward < "$HOME/armbian-build/patch/kernel/archive/rockchip64-6.18/rk3308-add-tsadc-driver.patch"
sed -n '62,68p' drivers/thermal/rockchip_thermal.c
sed -n '577,590p' drivers/thermal/rockchip_thermal.c
sed -n '629,642p' drivers/thermal/rockchip_thermal.c
sed -n '1101,1130p' drivers/thermal/rockchip_thermal.c
sed -n '1388,1405p' drivers/thermal/rockchip_thermal.c

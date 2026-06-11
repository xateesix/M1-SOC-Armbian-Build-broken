#!/usr/bin/env bash
set -euo pipefail
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone --depth 1 --branch v6.18 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$TMP/linux"
cd "$TMP/linux"
patch -p1 --forward < "$HOME/armbian-build/patch/kernel/archive/rockchip64-6.18/rk3308-add-tsadc-driver.patch"
grep -n 'struct chip_tsadc_table {' drivers/thermal/rockchip_thermal.c
grep -n 'rk_tsadcv2_temp_to_code' drivers/thermal/rockchip_thermal.c | head -1
grep -n 'rk_tsadcv2_code_to_temp' drivers/thermal/rockchip_thermal.c | head -1
grep -n 'rk3308_tsadc_data' drivers/thermal/rockchip_thermal.c
grep -n 'rk3308-tsadc' drivers/thermal/rockchip_thermal.c

#!/usr/bin/env bash
set -euo pipefail
AB="${ARMBIAN_BUILD_PATH:-/home/xateesix/scratch/Projects/rk3308bs-workspace/M1-SOC-Armbian-Build}"
K=$(find "$AB" -path '*/drivers/thermal/rockchip_thermal.c' 2>/dev/null | head -1)
echo "KERNEL_FILE=$K"
if [ -n "$K" ]; then
  grep -n 'rk3308\|kNum\|bNum\|of_rockchip_thermal_match' "$K" | head -40
fi
ls "$AB/cache/sources/" 2>/dev/null | head -15 || true

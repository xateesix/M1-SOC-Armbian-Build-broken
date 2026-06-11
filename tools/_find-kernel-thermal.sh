#!/usr/bin/env bash
set -euo pipefail
K=$(find "$HOME/armbian-build" -path '*/drivers/thermal/rockchip_thermal.c' 2>/dev/null | head -1)
echo "KERNEL_FILE=$K"
if [ -n "$K" ]; then
  grep -n 'rk3308\|kNum\|bNum\|of_rockchip_thermal_match' "$K" | head -40
fi
ls "$HOME/armbian-build/cache/sources/" 2>/dev/null | head -15 || true

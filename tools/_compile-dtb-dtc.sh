#!/bin/bash
set -euo pipefail
ARMBIAN_ROOT="${ARMBIAN_ROOT:-/home/xateesix/scratch/Projects/rk3308bs-workspace/M1-SOC-Armbian-Build}"
KWT="$ARMBIAN_ROOT/cache/sources/linux-kernel-worktree/6.18__rockchip64__arm64"
SRC=/tmp/rk3308bs-evb-amic-v11.dts
PRE=/tmp/rk3308bs-evb-amic-v11.pre.dts
OUT=/tmp/rk3308bs-evb-amic-v11.dtb
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I"$KWT/arch/arm64/boot/dts" \
  -I"$KWT/arch/arm64/boot/dts/rockchip" \
  -I"$KWT/include" \
  "$SRC" > "$PRE"
dtc -I dts -O dtb -o "$OUT" \
  -i "$KWT/arch/arm64/boot/dts" \
  -i "$KWT/arch/arm64/boot/dts/rockchip" \
  -i "$KWT/include" \
  "$PRE"
ls -la "$OUT"

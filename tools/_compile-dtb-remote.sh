#!/bin/bash
set -euo pipefail
KWT=/home/xateesix/armbian-build/cache/sources/linux-kernel-worktree/6.18__rockchip64__arm64
cd "$KWT"
patch -p1 --forward < /tmp/rk3308bs.patch || true
make ARCH=arm64 -j8 rockchip/rk3308bs-evb-amic-v11.dtb
ls -la arch/arm64/boot/dts/rockchip/rk3308bs-evb-amic-v11.dtb

#!/usr/bin/env bash
# v50: skip clk_disable_unused (hangs during eMMC HS200 tuning on 6.18).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
FAC="$SCRIPT_DIR/factory_fresh"
TOOLS="$SCRIPT_DIR/tools"
KERNEL="${1:-$REL/_Image-v22}"
[[ -f "$KERNEL" ]] || { echo "Missing $KERNEL"; exit 1; }

BOOTARGS="earlycon=uart8250,mmio32,0xff0d0000 console=ttyFIQ0 loglevel=7 clk_ignore_unused pd_ignore_unused root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v50.dtb" \
  --bootargs "$BOOTARGS" \
  --rk3308bs-tsadc \
  --rk3308-vop-resets \
  --rk3308-panel-dpi

fdtget "$REL/_fac-dtb-v50.dtb" /chosen bootargs

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v50.dtb" \
  --output "$REL/_resource-v50.img"

lz4 -f -9 "$KERNEL" "$REL/_kernel-v50.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v50.lz4" \
  --resource "$REL/_resource-v50.img" \
  --output "$REL/_boot-v50.img" \
  --cmdline "$BOOTARGS"

ls -la "$REL/_boot-v50.img"

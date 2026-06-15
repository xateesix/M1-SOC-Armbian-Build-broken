#!/usr/bin/env bash
# v57: v53 + console=tty0 (fbcon LCD status) + factory de-active=0 + Artillery logo resource.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
FAC="$SCRIPT_DIR/factory_fresh"
TOOLS="$SCRIPT_DIR/tools"
KERNEL="${1:-$REL/_Image-v22}"
[[ -f "$KERNEL" ]] || { echo "Missing $KERNEL"; exit 1; }

BOOTARGS="earlycon=uart8250,mmio32,0xff0d0000 console=tty0 console=ttyS3,1500000n8 loglevel=7 clk_ignore_unused pd_ignore_unused rootdelay=5 systemd.unit=multi-user.target root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v57.dtb" \
  --bootargs "$BOOTARGS" \
  --armbian-serial \
  --rk3308bs-tsadc \
  --rk3308-vop-resets \
  --rk3308-panel-dpi

fdtput -t s "$REL/_fac-dtb-v57.dtb" /mmc@ff480000 status disabled
fdtget "$REL/_fac-dtb-v57.dtb" /mmc@ff480000 status
fdtget "$REL/_fac-dtb-v57.dtb" /mmc@ff4a0000 status

RESOURCE_TEMPLATE="$REL/_resource-v56-logo.img"
[[ -f "$RESOURCE_TEMPLATE" ]] || RESOURCE_TEMPLATE="$FAC/04_boot_unpacked/resource.img"

python3 "$TOOLS/pack-resource-img.py" \
  --template "$RESOURCE_TEMPLATE" \
  --dtb "$REL/_fac-dtb-v57.dtb" \
  --output "$REL/_resource-v57.img"

lz4 -f -9 "$KERNEL" "$REL/_kernel-v57.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v57.lz4" \
  --resource "$REL/_resource-v57.img" \
  --output "$REL/_boot-v57.img" \
  --cmdline "$BOOTARGS"

cp -f "$REL/_boot-v57.img" "$REL/_boot-v56-logo.img"
echo "boot-v57 ok (tty0+ttyS3, de-active=0, logo resource)"


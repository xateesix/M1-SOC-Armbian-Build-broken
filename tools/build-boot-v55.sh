#!/usr/bin/env bash
# v55: v53 boot + resize initrd in ramdisk slot (offline fsck/resize before root mount).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
FAC="$SCRIPT_DIR/factory_fresh"
TOOLS="$SCRIPT_DIR/tools"
KERNEL="${1:-$REL/_Image-v22}"
[[ -f "$KERNEL" ]] || { echo "Missing $KERNEL"; exit 1; }

bash "$TOOLS/build-resize-initrd.sh" "$REL/rootfs-v54.img" "$REL/_resize-initrd-v55.cpio.gz"

BOOTARGS="earlycon=uart8250,mmio32,0xff0d0000 console=ttyS3,1500000n8 loglevel=7 clk_ignore_unused pd_ignore_unused rootdelay=5 systemd.unit=multi-user.target root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v55.dtb" \
  --bootargs "$BOOTARGS" \
  --armbian-serial \
  --rk3308bs-tsadc \
  --rk3308-vop-resets \
  --rk3308-panel-dpi

fdtput -t s "$REL/_fac-dtb-v55.dtb" /mmc@ff480000 status disabled

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v55.dtb" \
  --output "$REL/_resource-v55.img"

lz4 -f -9 "$KERNEL" "$REL/_kernel-v55.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v55.lz4" \
  --ramdisk "$REL/_resize-initrd-v55.cpio.gz" \
  --resource "$REL/_resource-v55.img" \
  --output "$REL/_boot-v55.img" \
  --cmdline "$BOOTARGS"

echo "boot-v55 ok"

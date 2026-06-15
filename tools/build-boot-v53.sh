#!/usr/bin/env bash
# v53: v52 + WiFi SDIO mmc@ff4a0000 enabled (SD slot stays disabled).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
FAC="$SCRIPT_DIR/factory_fresh"
TOOLS="$SCRIPT_DIR/tools"
KERNEL="${1:-$REL/_Image-v22}"
[[ -f "$KERNEL" ]] || { echo "Missing $KERNEL"; exit 1; }

BOOTARGS="earlycon=uart8250,mmio32,0xff0d0000 console=ttyS3,1500000n8 loglevel=7 clk_ignore_unused pd_ignore_unused rootdelay=5 systemd.unit=multi-user.target root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v53.dtb" \
  --bootargs "$BOOTARGS" \
  --armbian-serial \
  --rk3308bs-tsadc \
  --rk3308-vop-resets \
  --rk3308-panel-dpi

# Disable empty SD slot only; keep WiFi SDIO on ff4a0000.
fdtput -t s "$REL/_fac-dtb-v53.dtb" /mmc@ff480000 status disabled
fdtget "$REL/_fac-dtb-v53.dtb" /mmc@ff480000 status
fdtget "$REL/_fac-dtb-v53.dtb" /mmc@ff4a0000 status

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v53.dtb" \
  --output "$REL/_resource-v53.img"

lz4 -f -9 "$KERNEL" "$REL/_kernel-v53.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v53.lz4" \
  --resource "$REL/_resource-v53.img" \
  --output "$REL/_boot-v53.img" \
  --cmdline "$BOOTARGS"

echo "boot-v53 ok"

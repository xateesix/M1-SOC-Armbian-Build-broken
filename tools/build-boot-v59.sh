#!/usr/bin/env bash
# v59 boot: OUR DTB (simple-panel, no panel-dpi) + OUR logo patch + tty0 fbcon.
# panel-dpi breaks U-Boot logo; patch 0008 broke enable GPIO without pm_runtime.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
FAC="$SCRIPT_DIR/factory_fresh"
TOOLS="$SCRIPT_DIR/tools"
KERNEL="${1:-$REL/_Image-v22}"
[[ -f "$KERNEL" ]] || { echo "Missing $KERNEL"; exit 1; }

BOOTARGS="earlycon=uart8250,mmio32,0xff0d0000 console=tty0 console=ttyS3,1500000n8 loglevel=7 root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v59.dtb" \
  --bootargs "$BOOTARGS" \
  --armbian-serial \
  --rk3308bs-tsadc \
  --rk3308-vop-resets

fdtput -t s "$REL/_fac-dtb-v59.dtb" /mmc@ff480000 status disabled
dtc -I dtb -O dts "$REL/_fac-dtb-v59.dtb" 2>/dev/null | grep -q 'compatible = "simple-panel"' \
  || { echo "FAIL: expected simple-panel in v59 DTB"; exit 1; }

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v59.dtb" \
  --output "$REL/_resource-v59-base.img"

LOGO="$REL/_logo-artillery.bmp"
if [[ -f "$LOGO" ]]; then
  python3 "$TOOLS/patch-resource-logos.py" \
    --template "$REL/_resource-v59-base.img" \
    --logo "$LOGO" \
    --output "$REL/_resource-v59.img"
else
  cp -f "$REL/_resource-v59-base.img" "$REL/_resource-v59.img"
fi

lz4 -f -9 "$KERNEL" "$REL/_kernel-v59.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v59.lz4" \
  --resource "$REL/_resource-v59.img" \
  --output "$REL/_boot-v59.img" \
  --cmdline "$BOOTARGS"

echo "boot-v59 ok (simple-panel + logo patch, no panel-dpi)"

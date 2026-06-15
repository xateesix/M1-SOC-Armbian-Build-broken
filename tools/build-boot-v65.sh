#!/usr/bin/env bash
# v65 boot: v59 base + PWM0 lightbar in DTB.
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
  --output "$REL/_fac-dtb-v64-base.dtb" \
  --bootargs "$BOOTARGS" \
  --armbian-serial \
  --rk3308bs-tsadc \
  --rk3308-vop-resets

python3 "$TOOLS/patch-dtb-v64-lights.py" \
  --dtb "$REL/_fac-dtb-v64-base.dtb" \
  --output "$REL/_fac-dtb-v64.dtb"

# SD slot enabled for testing (factory: okay)
fdtput -t s "$REL/_fac-dtb-v64.dtb" /mmc@ff480000 status okay
dtc -I dtb -O dts "$REL/_fac-dtb-v64.dtb" 2>/dev/null | grep -q 'compatible = "simple-panel"' \
  || { echo "FAIL: expected simple-panel in v65 DTB"; exit 1; }

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v64.dtb" \
  --output "$REL/_resource-v64-base.img"

LOGO="$REL/_logo-artillery.bmp"
if [[ -f "$LOGO" ]]; then
  python3 "$TOOLS/patch-resource-logos.py" \
    --template "$REL/_resource-v64-base.img" \
    --logo "$LOGO" \
    --output "$REL/_resource-v64.img"
else
  cp -f "$REL/_resource-v64-base.img" "$REL/_resource-v64.img"
fi

lz4 -f -9 "$KERNEL" "$REL/_kernel-v64.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v64.lz4" \
  --resource "$REL/_resource-v64.img" \
  --output "$REL/_boot-v64.img" \
  --cmdline "$BOOTARGS"

echo "boot-v65 ok (simple-panel + pwm0 lightbar DTB)"


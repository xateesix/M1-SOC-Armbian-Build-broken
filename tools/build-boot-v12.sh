#!/usr/bin/env bash
set -euo pipefail
REL="$PROJECT_ROOT/output/releases/1.0.0"
FAC="$PROJECT_ROOT/output/factory_fresh"
TOOLS="$PROJECT_ROOT/output/tools"

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v12.dtb" \
  --armbian-serial \
  --disable-thermal-critical

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v12.dtb" \
  --output "$REL/_resource-v12.img"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel.lz4" \
  --resource "$REL/_resource-v12.img" \
  --output "$REL/_boot-v12.img" \
  --cmdline "earlycon=uart8250,mmio32,0xff0d0000 console=ttyS3,1500000n8 loglevel=7 root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

ls -la "$REL/_boot-v12.img" "$REL/_fac-dtb-v12.dtb" "$REL/_resource-v12.img"

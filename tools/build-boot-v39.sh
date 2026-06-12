#!/usr/bin/env bash
# v39 boot.img: v16 DT patches + panel-dpi timing for 480x272 RGB panel.
set -euo pipefail
REL="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0"
FAC="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/factory_fresh"
TOOLS="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/tools"

KERNEL="${1:-$REL/_Image-v22}"
[[ -f "$KERNEL" ]] || { echo "Missing $KERNEL"; exit 1; }

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v39.dtb" \
  --armbian-serial \
  --rk3308bs-tsadc \
  --rk3308-vop-resets \
  --rk3308-panel-dpi

# Sanity-check DTB panel node
fdtget "$REL/_fac-dtb-v39.dtb" /panel compatible | grep -q panel-dpi
fdtget "$REL/_fac-dtb-v39.dtb" /panel/panel-timing hactive | grep -q 480

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v39.dtb" \
  --output "$REL/_resource-v39.img"

lz4 -f -9 "$KERNEL" "$REL/_kernel-v39.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v39.lz4" \
  --resource "$REL/_resource-v39.img" \
  --output "$REL/_boot-v39.img" \
  --cmdline "earlycon=uart8250,mmio32,0xff0d0000 console=ttyS3,1500000n8 loglevel=7 root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

ls -la "$REL/_boot-v39.img" "$REL/_fac-dtb-v39.dtb"

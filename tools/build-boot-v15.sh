#!/usr/bin/env bash
# v15 boot.img: factory DTB + rk3308bs-tsadc + v15 kernel (built-in DRM + fbcon on LCD).
set -euo pipefail
REL="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0"
FAC="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/factory_fresh"
TOOLS="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/tools"

KERNEL="${1:-$REL/_Image-v15}"
if [ ! -f "$KERNEL" ]; then
  KERNEL="$REL/_Image-v14"
fi
if [ ! -f "$KERNEL" ]; then
  echo "Missing kernel Image (run build-kernel-v13-standalone.sh first)"
  exit 1
fi

BOOTARGS="earlycon=uart8250,mmio32,0xff0d0000 console=tty0 console=ttyS3,1500000n8 root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v15.dtb" \
  --armbian-serial \
  --rk3308bs-tsadc \
  --bootargs "$BOOTARGS"

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v15.dtb" \
  --output "$REL/_resource-v15.img"

lz4 -f -9 "$KERNEL" "$REL/_kernel-v15.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v15.lz4" \
  --resource "$REL/_resource-v15.img" \
  --output "$REL/_boot-v15.img" \
  --cmdline "earlycon=uart8250,mmio32,0xff0d0000 console=tty0 console=ttyS3,1500000n8 loglevel=7 root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

ls -la "$REL/_boot-v15.img" "$REL/_fac-dtb-v15.dtb"

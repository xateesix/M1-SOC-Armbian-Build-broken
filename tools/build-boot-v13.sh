#!/usr/bin/env bash
# Build v13 boot.img: factory DTB + rk3308bs-tsadc + patched kernel Image.
set -euo pipefail
REL="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0"
FAC="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/factory_fresh"
TOOLS="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/tools"

KERNEL="${1:-$REL/_Image-v13}"
if [ ! -f "$KERNEL" ]; then
  echo "Missing kernel Image: $KERNEL (run build-kernel-v13.sh first)"
  exit 1
fi

python3 "$TOOLS/patch-dtb-bootargs.py" \
  --from-factory-resource "$FAC/04_boot_unpacked/resource.img" \
  --output "$REL/_fac-dtb-v13.dtb" \
  --armbian-serial \
  --rk3308bs-tsadc

python3 "$TOOLS/pack-resource-img.py" \
  --template "$FAC/04_boot_unpacked/resource.img" \
  --dtb "$REL/_fac-dtb-v13.dtb" \
  --output "$REL/_resource-v13.img"

echo "=== LZ4 compress kernel ==="
lz4 -f -9 "$KERNEL" "$REL/_kernel-v13.lz4"

python3 "$TOOLS/pack-rockchip-bootimg.py" \
  --kernel "$REL/_kernel-v13.lz4" \
  --resource "$REL/_resource-v13.img" \
  --output "$REL/_boot-v13.img" \
  --cmdline "earlycon=uart8250,mmio32,0xff0d0000 console=ttyS3,1500000n8 loglevel=7 root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rootfstype=ext4 rw rootwait"

ls -la "$REL/_boot-v13.img" "$REL/_fac-dtb-v13.dtb"

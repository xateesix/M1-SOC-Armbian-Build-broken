#!/usr/bin/env bash
# Clean v64 intermediates and rebuild public flash image from rootfs base + all v64 patches.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
LOG="$SCRIPT_DIR/rebuild-from-scratch-v64.log"

exec > >(tee "$LOG") 2>&1
echo "=== rebuild-from-scratch-v64 $(date -Is) ==="

if [[ -f "$REL/rootfs-v61-private.bak" ]]; then
  cp -f "$REL/rootfs-v61-private.bak" "$REL/rootfs-v61.img"
  echo "Restored rootfs-v61.img from rootfs-v61-private.bak"
else
  echo "No backup; using current rootfs-v61.img"
fi

rm -f "$REL/_boot-v64.img" "$REL/rootfs-v64.img" "$REL/firmware.img"
rm -f "$REL/_fac-dtb-v64"*.dtb "$REL/_resource-v64"*.img "$REL/_fac-dtb-v64-base"*.dtb
rm -rf "$REL/pack_input_v64" "$REL/_rootfs-v64-stage"
rm -f "$REL/rk3308bs-1.0.0-emmc-fixed-v64.img" 2>/dev/null || true

for f in "$REL/_Image-v22" "$REL/rootfs-v61.img" "$REL/_uboot-memlayout.img" \
  "$SCRIPT_DIR/factory_fresh/04_boot_unpacked/resource.img" \
  "$SCRIPT_DIR/factory_fresh/03_partitions/MiniLoaderAll.bin" \
  "$REL/_modules_6.18.0-dirty/lib/modules/6.18.0-dirty/kernel/drivers/leds/leds-pwm.ko"; do
  [[ -f "$f" ]] || { echo "Missing $f"; exit 1; }
done
echo "Build inputs OK"

bash "$TOOLS/patch-rootfs-public-credentials-debugfs.sh" \
  "$REL/rootfs-v61.img" "$REL/rootfs-v61-public.img"
cp -f "$REL/rootfs-v61-public.img" "$REL/rootfs-v61.img"

bash "$TOOLS/build-boot-v64.sh" "$REL/_Image-v22"
bash "$TOOLS/patch-rootfs-v64-debugfs.sh" "$REL/rootfs-v61.img" "$REL/rootfs-v64.img"
bash "$TOOLS/stage-pack-v64.sh"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$TOOLS/pack-v64-release.ps1")"

ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v64.img"
echo "=== finished $(date -Is) ==="
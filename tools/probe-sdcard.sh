#!/usr/bin/env bash
# Run on the board after inserting an SD card (optional  -  documents MMC topology).
set -euo pipefail

echo "=== lsblk ==="
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,TRAN 2>/dev/null || lsblk

echo
echo "=== mmc block devices ==="
for d in /sys/block/mmcblk*; do
	[[ -d "$d" ]] || continue
	name="$(basename "$d")"
	echo "--- $name ---"
	cat "$d/device/name" 2>/dev/null && true
	cat "$d/device/type" 2>/dev/null && true
	cat "$d/size" 2>/dev/null | awk '{printf "sectors: %s (%.1f MiB)\n", $1, $1*512/1024/1024}'
done

echo
echo "=== dmesg mmc (last 40 lines) ==="
dmesg 2>/dev/null | grep -iE 'mmc|sdhci|dwmmc' | tail -40 || true

echo
echo "=== mount by-partuuid / fstab ==="
findmnt -r -o SOURCE,TARGET,FSTYPE,SIZE 2>/dev/null | head -20
[[ -f /etc/fstab ]] && grep -v '^#' /etc/fstab | grep -v '^$' || true

echo
echo "=== RK3308BS hint ==="
echo "mmc0 = SDIO WiFi | mmc1 = SD slot (typ.) | mmc2 = eMMC (typ.)"
echo "Save this output when testing SD boot path."

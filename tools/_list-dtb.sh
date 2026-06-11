#!/bin/bash
IMG="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian-unofficial_26.08.0-trunk_Rk3308bs-evb_bookworm_current_6.18.35_minimal.img"
LOOP=$(losetup -f --show -P "$IMG")
partprobe "$LOOP" 2>/dev/null || sleep 1
mkdir -p /tmp/armmnt
mount -o ro "${LOOP}p1" /tmp/armmnt
echo "=== boot tree ==="
ls -la /tmp/armmnt/boot/
find /tmp/armmnt/boot -name '*.dtb' | head -40
find /tmp/armmnt/boot -iname '*rk3308*' | head -20
umount /tmp/armmnt
losetup -d "$LOOP"

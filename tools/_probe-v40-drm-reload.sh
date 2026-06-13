#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:s1rHSunbpOXwkJ1bHnbtYD0KbAVeaLLtPx897zRHTrM"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
ls /sys/kernel/debug/dri/ 2>&1
cat /sys/devices/platform/panel/waiting_for_supplier 2>&1
# rockchip drm reload
M=/lib/modules/$(uname -r)/kernel
while lsmod | grep -q rockchipdrm; do rmmod rockchipdrm 2>/dev/null || break; done
insmod $M/drivers/gpu/drm/rockchip/rockchipdrm.ko 2>&1 || true
sleep 1
dmesg | grep -iE "rgb|failed to find panel|panel-simple registered" | tail -15
ls /sys/class/drm/ 2>&1
REMOTE

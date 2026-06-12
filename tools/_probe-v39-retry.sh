#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:M2Ft/9qechrx7LzpfzCesjw+Ea0FLSjGN3IS7xAr2/g"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
echo 1 > /sys/kernel/debug/devices_deferred/scan 2>/dev/null || true
sleep 1
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1 || echo bind_fail
sleep 1
ls -la /sys/bus/platform/drivers/panel-simple/
readlink /sys/devices/platform/panel/driver 2>&1 || echo NO_DRIVER
dmesg | grep -iE 'panel|backlight|rgb|failed to find|Could not|gpiod|Specify' | tail -30
ls /sys/class/drm/ /sys/class/graphics/ 2>&1
REMOTE

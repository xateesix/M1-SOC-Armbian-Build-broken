#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:s1rHSunbpOXwkJ1bHnbtYD0KbAVeaLLtPx897zRHTrM"
PW="ztfalxtspv"
IP="${1:-10.22.30.172}"
"$PLINK" -batch -hostkey "$HK" -pw "$PW" "root@$IP" 'bash -s' <<'REMOTE'
echo HOST=$(hostname) K=$(uname -r)
ls -la /sys/bus/platform/drivers/panel-simple/
readlink /sys/devices/platform/panel/driver 2>&1 || echo NO_DRIVER
ls /sys/bus/platform/drivers/rockchip-rgb/ 2>&1
ls /sys/class/drm/ /sys/class/graphics/ 2>&1
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
cat /sys/kernel/debug/devices_deferred 2>&1
dmesg | grep -iE "panel-simple|panel-dpi|rockchip-rgb|rockchip-drm|fb0|registered|backlight not|enable GPIO|failed to find panel|Specify" | tail -60
REMOTE

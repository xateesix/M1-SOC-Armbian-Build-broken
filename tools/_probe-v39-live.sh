#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:M2Ft/9qechrx7LzpfzCesjw+Ea0FLSjGN3IS7xAr2/g"
PW="ztfalxtspv"
IP="${1:-10.22.30.172}"
"$PLINK" -batch -hostkey "$HK" -pw "$PW" "root@$IP" 'bash -s' <<'REMOTE'
echo "=== $(hostname) ==="
ls -la /sys/bus/platform/drivers/panel-simple/ 2>&1
readlink /sys/devices/platform/panel/driver 2>&1 || echo NO_DRIVER
ls -la /sys/bus/platform/drivers/rockchip-rgb/ 2>&1
ls /sys/class/backlight/ 2>&1
ls /sys/class/drm/ /sys/class/graphics/ 2>&1
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
cat /sys/kernel/debug/devices_deferred 2>&1
dmesg | grep -iE 'panel|backlight|rgb|rockchip-drm|display-subsystem|failed|defer|warn|Specify' | tail -80
REMOTE

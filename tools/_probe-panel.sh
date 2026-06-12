#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HOST="root@10.22.30.172"
HK="SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE"
PW="ztfalxtspv"

"$PLINK" -batch -hostkey "$HK" -pw "$PW" "$HOST" <<'REMOTE'
echo "=== panel device ==="
ls -la /sys/devices/platform/panel/ 2>&1
echo "=== uevent ==="
cat /sys/devices/platform/panel/uevent 2>&1
echo "=== compatible ==="
tr '\0' '\n' < /proc/device-tree/panel/compatible 2>&1
echo "=== driver link ==="
readlink /sys/devices/platform/panel/driver 2>&1 || true
echo "=== deferred ==="
cat /sys/kernel/debug/devices_deferred 2>&1 | head -20
echo "=== dmesg panel/rgb ==="
dmesg | grep -iE 'panel|rgb|display.timing|rockchip-drm|fb0' | head -80
echo "=== try bind ==="
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1
dmesg | tail -5
REMOTE

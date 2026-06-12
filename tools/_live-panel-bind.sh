#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HOST="root@10.22.30.172"
HK="SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE"
PW="ztfalxtspv"

"$PLINK" -batch -hostkey "$HK" -pw "$PW" "$HOST" 'bash -s' <<'REMOTE'
set -x
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true

# Test 1: driver_override to panel-simple (force OF bypass)
echo panel-simple > /sys/devices/platform/panel/driver_override
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1 || true
sleep 0.5
ls -la /sys/bus/platform/drivers/panel-simple/
dmesg | tail -20

# Test 2: if still unbound, try deferred scan + rockchipdrm reload
echo 1 > /sys/kernel/debug/devices_deferred/scan 2>/dev/null || true
sleep 1
ls /sys/class/drm/ 2>&1
REMOTE

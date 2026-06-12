#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
"$PLINK" -batch -hostkey SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
echo "=== driver uevent ==="
cat /sys/bus/platform/drivers/panel-simple/uevent 2>&1
echo "=== bind with strace would help - check probe_defer ==="
cat /sys/devices/platform/panel/waiting_for_supplier
cat /sys/devices/platform/panel/driver_override
# unbind override and set to panel-dpi
echo panel-dpi > /sys/devices/platform/panel/driver_override
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1 || echo bind_dpi_fail
sleep 0.3
readlink /sys/devices/platform/panel/driver 2>&1 || echo no_drv
dmesg | tail -8
REMOTE

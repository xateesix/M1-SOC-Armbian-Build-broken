#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
"$PLINK" -batch -hostkey SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
echo panel-simple > /sys/devices/platform/panel/driver_override
cat /sys/devices/platform/panel/driver_override
if echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>/tmp/binderr; then
  echo BIND_OK
else
  echo BIND_FAIL
  cat /tmp/binderr
fi
readlink /sys/devices/platform/panel/driver 2>&1 || echo NO_DRIVER
dmesg | grep -iE 'panel|timing|display|simple' | tail -25
REMOTE

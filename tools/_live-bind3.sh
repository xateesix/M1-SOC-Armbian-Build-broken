#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
"$PLINK" -batch -hostkey SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
echo "dev name: $(basename /sys/devices/platform/panel)"
ls /sys/bus/platform/devices/ | grep panel
for d in /sys/bus/platform/devices/*panel*; do echo "$d -> $(cat $d/uevent 2>/dev/null | head -3)"; done
# try bind with full platform device name
for name in panel platform:panel; do
  echo "try bind name=$name"
  echo "$name" > /sys/bus/platform/drivers/panel-simple/bind 2>&1 && echo OK || echo FAIL
done
REMOTE

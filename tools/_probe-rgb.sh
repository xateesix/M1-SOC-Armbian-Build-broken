#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HOST="root@10.22.30.172"
HK="SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE"
PW="ztfalxtspv"

"$PLINK" -batch -hostkey "$HK" -pw "$PW" "$HOST" 'bash -s' <<'REMOTE'
echo "=== rgb device ==="
ls -la /sys/devices/platform/rgb/ 2>&1
echo "=== rgb waiting_for_supplier ==="
cat /sys/devices/platform/rgb/waiting_for_supplier 2>&1
echo "=== panel waiting_for_supplier ==="
cat /sys/devices/platform/panel/waiting_for_supplier 2>&1
echo "=== rgb driver ==="
readlink /sys/devices/platform/rgb/driver 2>&1
echo "=== devlinks rgb ==="
ls /sys/devices/platform/rgb/ | grep devlink
find /sys/class/devlink -name '*rgb*' 2>/dev/null | head -10
for f in /sys/class/devlink/*rgb*; do echo "$f:"; cat "$f/status" 2>/dev/null; done
echo "=== display-subsystem ==="
ls -la /sys/devices/platform/display-subsystem/ 2>&1 | head -15
cat /sys/devices/platform/display-subsystem/waiting_for_supplier 2>&1
REMOTE

#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
"$PLINK" -batch -hostkey SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
echo "=== strings check ==="
strings /boot/vmlinuz-* 2>/dev/null | grep -E 'simple-panel|using fallback timing|failed to parse display' | head -5
strings /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/panel-simple.ko 2>/dev/null | head -1 || echo no_panel_ko
# reset override
echo > /sys/devices/platform/panel/driver_override
cat /sys/devices/platform/panel/driver_override
# trigger reprobe
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1 || echo bind_fail
dmesg | tail -10
REMOTE

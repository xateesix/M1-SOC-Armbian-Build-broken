#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
"$PLINK" -batch -hostkey SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
grep PANEL_SIMPLE /proc/config.gz 2>/dev/null | zcat /proc/config.gz 2>/dev/null | grep PANEL
lsmod | grep panel
ls /sys/module/ | grep panel
# Check if driver name matches override
basename $(readlink /sys/bus/platform/drivers/panel-simple 2>/dev/null) 2>/dev/null || true
ls -la /sys/bus/platform/drivers/panel-simple/
REMOTE

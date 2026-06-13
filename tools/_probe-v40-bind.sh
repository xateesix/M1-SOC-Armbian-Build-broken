#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:s1rHSunbpOXwkJ1bHnbtYD0KbAVeaLLtPx897zRHTrM"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
dmesg | grep -iE 'panel|backlight|gpiod|orientation|regulator|drm_panel|Specify|Unexpected|Could not' | grep -iv registered | tail -40
echo "--- try bind ---"
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1; echo ec=$?
sleep 0.3
readlink /sys/devices/platform/panel/driver 2>&1 || echo NO_DRIVER
dmesg | tail -15
REMOTE

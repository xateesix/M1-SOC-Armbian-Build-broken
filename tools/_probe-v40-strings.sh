#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:s1rHSunbpOXwkJ1bHnbtYD0KbAVeaLLtPx897zRHTrM"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
grep -a "enable GPIO defer" /proc/kallsyms 2>/dev/null || strings /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/panel-simple.ko 2>/dev/null | grep -E "enable GPIO|backlight not ready|panel-simple registered" || true
# panel-simple is built-in - check via config
zcat /proc/config.gz 2>/dev/null | grep PANEL_SIMPLE
# check if panel in deferred
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
grep panel /sys/kernel/debug/devices_deferred 2>/dev/null || true
# dynamic debug one line after bind
echo 'file panel-simple.c +p' > /sys/kernel/debug/dynamic_debug/control 2>/dev/null || true
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1
sleep 0.2
dmesg | grep panel-simple | tail -10
REMOTE

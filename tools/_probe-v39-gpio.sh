#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:M2Ft/9qechrx7LzpfzCesjw+Ea0FLSjGN3IS7xAr2/g"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
echo -n "backlight phandle: "; od -An -tx4 /proc/device-tree/backlight/phandle
echo -n "panel->backlight ref: "; od -An -tx4 /proc/device-tree/panel/backlight
echo -n "enable-gpios: "; od -An -tx4 /proc/device-tree/panel/enable-gpios
echo -n "reset-gpios: "; od -An -tx4 /proc/device-tree/panel/reset-gpios
# check if panel-dpi in modalias matches
cat /sys/devices/platform/panel/modalias
# try driver_override bind
echo panel-simple > /sys/devices/platform/panel/driver_override
echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>&1; echo bind=$?
sleep 0.5
readlink /sys/devices/platform/panel/driver 2>&1 || echo NO_DRIVER
dmesg | tail -8
REMOTE

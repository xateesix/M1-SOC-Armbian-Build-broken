#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:M2Ft/9qechrx7LzpfzCesjw+Ea0FLSjGN3IS7xAr2/g"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
for f in waiting_for_supplier driver_override uevent; do
  echo -n "panel $f: "
  cat /sys/devices/platform/panel/$f 2>&1
done
echo "rgb driver: $(readlink /sys/devices/platform/rgb/driver 2>&1)"
echo "backlight: $(ls /sys/class/backlight/)"
# modetest if available
modetest -M rockchip 2>&1 | head -20 || true
REMOTE

#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:M2Ft/9qechrx7LzpfzCesjw+Ea0FLSjGN3IS7xAr2/g"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'dmesg | grep -i panel'
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'dmesg | grep -iE "panel-simple|failed to request|Could not find backlight|Specify missing|Unexpected bus|gpiod|panel:"'

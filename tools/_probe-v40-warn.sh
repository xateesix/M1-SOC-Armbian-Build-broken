#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:s1rHSunbpOXwkJ1bHnbtYD0KbAVeaLLtPx897zRHTrM"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'dmesg | grep -iE "Specify|Unexpected|enable GPIO|backlight not|failed to request|orientation|panel-simple"'

#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:s1rHSunbpOXwkJ1bHnbtYD0KbAVeaLLtPx897zRHTrM"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'ls /proc/device-tree/panel/; echo ---; for p in power-supply vdd-supply power enable-gpios; do echo -n "$p: "; cat /proc/device-tree/panel/$p 2>&1 | head -1; done'

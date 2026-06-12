#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:M2Ft/9qechrx7LzpfzCesjw+Ea0FLSjGN3IS7xAr2/g"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
echo "panel compatible: $(tr "\0" " " < /proc/device-tree/panel/compatible)"
echo -n "panel backlight phandle bytes: "; od -An -tx1 /proc/device-tree/panel/backlight 2>&1
echo -n "backlight node name: "; ls /proc/device-tree/ | grep -i back
for n in backlight panel; do
  echo "=== $n ==="
  ls /proc/device-tree/$n/ 2>&1 | head -15
done
# resolve phandle target
ph=$(od -An -td4 /proc/device-tree/panel/backlight 2>/dev/null | tr -d " ")
echo "panel backlight phandle=$ph"
find /proc/device-tree -name phandle -exec sh -c 'v=$(od -An -td4 "$1" 2>/dev/null); [ "$v" = " $ph " ] || [ "$v" = "$ph " ] && echo MATCH:$1' _ {} \; 2>/dev/null | head -5
REMOTE

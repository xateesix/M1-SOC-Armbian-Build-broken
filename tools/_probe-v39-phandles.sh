#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:M2Ft/9qechrx7LzpfzCesjw+Ea0FLSjGN3IS7xAr2/g"
"$PLINK" -batch -hostkey "$HK" -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
for p in a2 a3 21; do
  echo "=== phandle 0x$p ==="
  find /proc/device-tree -name phandle 2>/dev/null | while read f; do
    v=$(od -An -tx4 "$f" 2>/dev/null | tr -d " \n")
    if [ "$v" = "$(printf '%08x' $((0x$p)))" ] || [ "$v" = "${p}000000" ]; then
      dir=$(dirname "$f")
      echo "  $dir compatible=$(tr "\0" " " < $dir/compatible 2>/dev/null)"
    fi
  done
done
REMOTE

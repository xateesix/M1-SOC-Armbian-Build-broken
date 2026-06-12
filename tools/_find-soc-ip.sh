#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
HK="SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE"
PW="ztfalxtspv"
for ip in 10.22.30.172 10.22.30.227 10.22.30.72 10.22.30.173 10.22.30.174; do
  out=$("$PLINK" -batch -hostkey "$HK" -pw "$PW" "root@$ip" hostname 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "FOUND $ip -> $out"
    exit 0
  fi
  echo "no $ip"
done
echo "NOT_FOUND"
exit 1

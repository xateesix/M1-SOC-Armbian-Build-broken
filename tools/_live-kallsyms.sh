#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
"$PLINK" -batch -hostkey SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE -pw ztfalxtspv root@10.22.30.172 'bash -s' <<'REMOTE'
grep -i 'simple-panel\|fallback timing\|panel_simple_from' /proc/kallsyms 2>/dev/null | head -5
grep -a 'simple-panel' /sys/firmware/efi 2>/dev/null | head -1 || true
# search in uncompressed kernel if available
for f in /boot/Image /boot/image.itb /usr/lib/linux-image*/vmlinuz; do
  [[ -f "$f" ]] && strings "$f" 2>/dev/null | grep -m1 'simple-panel' && echo "found in $f"
done
# Check platform_of_match in debug
mount -t debugfs debug /sys/kernel/debug 2>/dev/null || true
grep -r simple-panel /sys/kernel/debug 2>/dev/null | head -3
REMOTE

#!/bin/bash
IMG="$1"
for f in /etc/issue /etc/motd /etc/rk3308bs-release /etc/profile.d/rk3308bs-banner.sh /boot/banner.txt; do
  echo "=== $f ==="
  if debugfs -R "dump $f /tmp/rkbf" "$IMG" 2>/dev/null; then cat /tmp/rkbf | head -8; else echo missing; fi
done
debugfs -R "ls -l /etc/profile.d" "$IMG" 2>&1 | head -15

#!/bin/bash
IMG="$1"
for f in /boot/system.cfg /etc/netplan/01-rk3308bs-wlan0.yaml; do
  echo "=== $f ==="
  debugfs -R "dump $f /tmp/wifichk" "$IMG" 2>&1 | tail -1
  cat /tmp/wifichk 2>/dev/null || echo "(missing)"
done

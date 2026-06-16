#!/bin/bash
IMG="$1"
for f in /boot/system.cfg /etc/wpa_supplicant/wpa_supplicant-wlan0.conf /etc/wpa_supplicant/wpa_supplicant.conf; do
  echo "=== $f ==="
  debugfs -R "dump $f /tmp/wifichk" "$IMG" 2>&1 | tail -1
  cat /tmp/wifichk 2>/dev/null || echo "(missing)"
done

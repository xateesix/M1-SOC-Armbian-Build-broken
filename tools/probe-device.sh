#!/usr/bin/env bash
set -euo pipefail
HOST="${1:-10.22.30.171}"
PASS="${2:-ztfalxtspv}"
REMOTE='cat /etc/rk3308bs-release
echo "--- dmesg display ---"
dmesg | grep -iE "gamma|rockchip-vop|rockchip-drm|panel-simple|fb0|RK3308BS-LCD" | tail -40
echo "--- drm ---"
ls -la /sys/class/drm/ 2>&1 || true
ls /sys/class/drm/card0-* 2>&1 || true
echo "--- fb ---"
ls -la /sys/class/graphics/ 2>&1 || true
echo "--- wifi ---"
ip -4 addr show wlan0 2>&1 || true
wpa_cli -i wlan0 status 2>&1 | head -5 || true'

if command -v sshpass >/dev/null 2>&1; then
  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 "root@$HOST" "$REMOTE"
elif [[ -x "/mnt/c/Program Files/PuTTY/plink.exe" ]]; then
  "/mnt/c/Program Files/PuTTY/plink.exe" -batch -pw "$PASS" "root@$HOST" "$REMOTE"
else
  echo "Need sshpass or PuTTY plink for non-interactive SSH"
  exit 1
fi

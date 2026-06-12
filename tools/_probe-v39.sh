#!/bin/bash
PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
PW="ztfalxtspv"
REMOTE='echo HOST=$(hostname) IP=$(hostname -I)
echo "=== panel driver ==="
ls -la /sys/bus/platform/drivers/panel-simple/ 2>&1
readlink /sys/devices/platform/panel/driver 2>&1 || echo NO_DRIVER
echo "=== rgb ==="
ls -la /sys/bus/platform/drivers/rockchip-rgb/ 2>&1
echo "=== drm/fb ==="
ls -la /sys/class/drm/ /sys/class/graphics/ 2>&1
echo "=== deferred ==="
mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
cat /sys/kernel/debug/devices_deferred 2>&1
echo "=== dmesg ==="
dmesg | grep -iE "panel|rgb|rockchip-drm|display-subsystem|fb0|failed|error|defer" | tail -60'

for ip in 10.22.30.171 10.22.30.172; do
  for hk in \
    "SHA256:Hr06v1r2w6qd0YqAqB0IzilokHSGWEJzAnlmmilkcPE" \
    ""; do
    args=(-batch -pw "$PW")
    [[ -n "$hk" ]] && args+=(-hostkey "$hk")
    if out=$("$PLINK" "${args[@]}" "root@$ip" "$REMOTE" 2>&1); then
      echo "=== FOUND $ip ==="
      echo "$out"
      exit 0
    fi
  done
done
echo "SSH failed on both IPs"
exit 1

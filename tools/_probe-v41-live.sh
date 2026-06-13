#!/bin/bash
PW="ztfalxtspv"
for IP in 10.22.30.172 10.22.30.171; do
  echo "=== trying $IP ==="
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 root@"$IP" 'bash -s' <<'REMOTE' && exit 0
echo HOST=$(hostname) K=$(uname -r)
echo "--- panel-simple driver ---"
ls -la /sys/bus/platform/drivers/panel-simple/
echo "--- rockchip-rgb driver ---"
ls -la /sys/bus/platform/drivers/rockchip-rgb/ 2>&1
echo "--- drm / fb ---"
ls -la /sys/class/drm/ /sys/class/graphics/ 2>&1
echo "--- dmesg display ---"
dmesg | grep -iE 'panel-simple|rockchip-rgb|rockchip-drm|rockchipdrm|fb0|display-subsystem|failed to find panel|component bind' | tail -40
REMOTE
done
exit 1

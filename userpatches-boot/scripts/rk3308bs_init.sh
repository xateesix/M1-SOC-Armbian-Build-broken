#!/bin/bash
# First-boot hook: apply /boot/system.cfg (hostname, TZ, WiFi). Safe to re-run after editing cfg on PC.
set -euo pipefail

log_file="/boot/scripts/boot.log"
mkdir -p /boot/scripts
echo "$(date) ===> rk3308bs_init start" >>"$log_file"

/boot/scripts/system_cfg.sh >>"$log_file" 2>&1 || true
/boot/scripts/sync_wifi_from_cfg.sh >>"$log_file" 2>&1 || true

echo "$(date) ===> rk3308bs_init done" >>"$log_file"

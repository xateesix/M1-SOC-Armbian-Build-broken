#!/bin/bash
# Apply hostname and timezone from /boot/system.cfg (BTT-style, networkd/wpa stack).
set -euo pipefail

SYSTEM_CFG_PATH="/boot/system.cfg"
[[ -f "$SYSTEM_CFG_PATH" ]] || exit 0

# shellcheck disable=SC1090
source "$SYSTEM_CFG_PATH"

if grep -qE '^hostname=' "$SYSTEM_CFG_PATH"; then
	cur_name="$(hostname)"
	if [[ "$cur_name" != "$hostname" ]]; then
		hostnamectl set-hostname "$hostname" 2>/dev/null || echo "$hostname" >/etc/hostname
	fi
fi

if grep -qE '^TimeZone=' "$SYSTEM_CFG_PATH"; then
	timedatectl set-timezone "$TimeZone" 2>/dev/null || true
fi

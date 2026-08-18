#!/bin/bash
# Sync netplan from /boot/system.cfg (edit WiFi on PC without rebuilding image).
set -euo pipefail

cfg_file="/boot/system.cfg"
netplan_conf="/etc/netplan/01-rk3308bs-wlan0.yaml"
log_file="/boot/scripts/wifi.log"

[[ -f "$cfg_file" ]] || exit 0
grep -qE '^WIFI_SSID=' "$cfg_file" || exit 0

# shellcheck disable=SC1090
source "$cfg_file"

: "${wlan:=wlan0}"
: "${WIFI_PASSWD:=${WIFI_PASSWORD:-}}"

if [[ -z "${WIFI_SSID:-}" || -z "${WIFI_PASSWD:-}" ]]; then
	echo "$(date) ===> WIFI_SSID or WIFI_PASSWD empty in system.cfg" >>"$log_file"
	exit 0
fi

yaml_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	printf '%s' "$value"
}

tmp="$(mktemp)"
cat >"$tmp" <<EOF
network:
  version: 2
  renderer: networkd
  wifis:
    "${wlan}":
      optional: true
      dhcp4: true
      access-points:
        "$(yaml_escape "$WIFI_SSID")":
          password: "$(yaml_escape "$WIFI_PASSWD")"
EOF

if [[ ! -f "$netplan_conf" ]] || ! cmp -s "$tmp" "$netplan_conf"; then
	cp "$tmp" "$netplan_conf"
	chmod 600 "$netplan_conf"
	echo "$(date) ===> Updated $netplan_conf from system.cfg (SSID=${WIFI_SSID})" >>"$log_file"
	netplan apply 2>/dev/null || systemctl restart systemd-networkd.service 2>/dev/null || true
fi
rm -f "$tmp"

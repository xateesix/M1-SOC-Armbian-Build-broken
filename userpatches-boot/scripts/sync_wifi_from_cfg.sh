#!/bin/bash
# Sync wpa_supplicant from /boot/system.cfg (edit WiFi on PC without rebuilding image).
set -euo pipefail

cfg_file="/boot/system.cfg"
wpa_conf="/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"
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

country="${WIFI_COUNTRY:-US}"
tmp="$(mktemp)"
cat >"$tmp" <<EOF
country=${country}
ctrl_interface=/var/run/wpa_supplicant
update_config=0

network={
	ssid="${WIFI_SSID}"
	psk="${WIFI_PASSWD}"
	key_mgmt=WPA-PSK
}
EOF

if [[ ! -f "$wpa_conf" ]] || ! cmp -s "$tmp" "$wpa_conf"; then
	cp "$tmp" "$wpa_conf"
	chmod 600 "$wpa_conf"
	echo "$(date) ===> Updated $wpa_conf from system.cfg (SSID=${WIFI_SSID})" >>"$log_file"
	systemctl try-restart wpa-wlan0.service 2>/dev/null || true
fi
rm -f "$tmp"

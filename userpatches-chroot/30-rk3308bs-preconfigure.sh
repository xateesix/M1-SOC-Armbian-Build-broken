#!/bin/bash
# Bake locale, timezone, users, and WiFi into rootfs during compile.sh (no first-boot wizard).
set -euo pipefail

ROOT_PASSWORD="${ROOT_PASSWORD:?ROOT_PASSWORD required}"
USER_NAME="${USER_NAME:-m1prox1}"
USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
USER_REALNAME="${USER_REALNAME:-$USER_NAME}"
LOCALE="${LOCALE:-en_US.UTF-8}"
TIMEZONE="${TIMEZONE:-America/Los_Angeles}"
WIFI_SSID="${WIFI_SSID:-}"
WIFI_PASSWORD="${WIFI_PASSWORD:-}"

export DEBIAN_FRONTEND=noninteractive

echo "[rk3308bs] Pre-configuring root password ..."
echo "root:${ROOT_PASSWORD}" | chpasswd -c SHA512

echo "[rk3308bs] Locale ${LOCALE} ..."
if grep -q "^# ${LOCALE} UTF-8" /etc/locale.gen 2>/dev/null; then
	sed -i "s/^# ${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
elif ! grep -q "^${LOCALE} UTF-8" /etc/locale.gen 2>/dev/null; then
	echo "${LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen "${LOCALE}" >/dev/null 2>&1 || locale-gen
update-locale LANG="${LOCALE}" LC_ALL="${LOCALE}" LANGUAGE="${LOCALE}"

echo "[rk3308bs] Timezone ${TIMEZONE} ..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
echo "${TIMEZONE}" >/etc/timezone
dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true

echo "[rk3308bs] User ${USER_NAME} ..."
if ! id "$USER_NAME" &>/dev/null; then
	useradd -m -s /bin/bash -c "$USER_REALNAME" "$USER_NAME"
fi
echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd -c SHA512
usermod -aG sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input,render,netdev "$USER_NAME" 2>/dev/null \
	|| usermod -aG sudo "$USER_NAME"

if [[ -n "$WIFI_SSID" && -n "$WIFI_PASSWORD" ]]; then
	echo "[rk3308bs] WiFi ${WIFI_SSID} ..."
	mkdir -p /etc/wpa_supplicant
	cat >/etc/wpa_supplicant/wpa_supplicant.conf <<EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=1

network={
    ssid="${WIFI_SSID}"
    psk="${WIFI_PASSWORD}"
    key_mgmt=WPA-PSK
    priority=100
}
EOF
	chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
fi

rm -f /root/.not_logged_in_yet
echo "[rk3308bs] First-boot wizard disabled (.not_logged_in_yet removed)"

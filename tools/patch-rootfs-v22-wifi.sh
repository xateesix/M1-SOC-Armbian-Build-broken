#!/usr/bin/env bash
# Rootfs: Armbian firstrun + OurIOT WiFi + grow rootfs + wpa_supplicant/networkd at boot.
# NEVER use debugfs set_inode_field (corrupts ext4 inodes).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v24.img}"
IMAGE_TAG="${RK3308BS_IMAGE_TAG:-v28-wifi-display-grow}"

[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG"; exit 1; }
[[ -f "$SRC" ]] || { echo "Missing rootfs: $SRC"; exit 1; }
command -v debugfs >/dev/null || { echo "Install e2fsprogs (debugfs)"; exit 1; }

# shellcheck source=/dev/null
source "$CONFIG"
USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
USER_NAME="${USER_NAME:-xateesix}"
USER_REALNAME="${USER_REALNAME:-$USER_NAME}"
LOCALE="${LOCALE:-en_US.UTF-8}"
TIMEZONE="${TIMEZONE:-America/Los_Angeles}"
WIFI_COUNTRY="${WIFI_COUNTRY:-US}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DST="$WORKDIR/rootfs.img"
cp "$SRC" "$DST"

NO_RESIZE="$WORKDIR/no_rootfs_resize"
: >"$NO_RESIZE"
FIRSTBOOT="$WORKDIR/not_logged_in_yet"
SERIAL_GETTY="$WORKDIR/serial-root-autologin.conf"
RELEASE="$WORKDIR/rk3308bs-release"
ISSUE="$WORKDIR/issue"
HOSTNAME="$WORKDIR/hostname"
GROW_SH="$WORKDIR/rk3308bs-grow-rootfs.sh"
GROW_UNIT="$WORKDIR/rk3308bs-grow-rootfs.service"
WPA_CONF="$WORKDIR/wpa_supplicant-wlan0.conf"
NETDEV="$WORKDIR/25-wlan0.network"
WPA_UNIT="$WORKDIR/wpa-wlan0.service"
WANTS_DROPIN="$WORKDIR/rk3308bs.conf"

{
	echo "# RK3308BS — Armbian non-interactive first boot + WiFi"
	echo "PRESET_ROOT_PASSWORD=\"$ROOT_PASSWORD\""
	echo "PRESET_USER_NAME=\"$USER_NAME\""
	echo "PRESET_USER_PASSWORD=\"$USER_PASSWORD\""
	echo "PRESET_DEFAULT_REALNAME=\"$USER_REALNAME\""
	echo "PRESET_LOCALE=\"$LOCALE\""
	echo "PRESET_TIMEZONE=\"$TIMEZONE\""
	echo "SET_LANG_BASED_ON_LOCATION=\"n\""
	echo "PRESET_CONNECT_WIRELESS=\"n\""
	if [[ -n "${WIFI_SSID:-}" && -n "${WIFI_PASSWORD:-}" ]]; then
		echo "PRESET_NET_CHANGE_DEFAULTS=\"1\""
		echo "PRESET_NET_WIFI_ENABLED=\"1\""
		echo "PRESET_NET_WIFI_SSID=\"$WIFI_SSID\""
		echo "PRESET_NET_WIFI_KEY=\"$WIFI_PASSWORD\""
		echo "PRESET_NET_WIFI_COUNTRYCODE=\"$WIFI_COUNTRY\""
	else
		echo "PRESET_NET_CHANGE_DEFAULTS=\"0\""
	fi
} >"$FIRSTBOOT"

cat >"$SERIAL_GETTY" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --keep-baud 115200,1500000,9600 --noclear %I $TERM
Type=idle
EOF

cat >"$GROW_SH" <<'EOF'
#!/bin/bash
set -euo pipefail
MARKER=/root/.rk3308bs_rootfs_grown
[[ -f "$MARKER" ]] && exit 0
ROOT_PART=$(findmnt -n -o SOURCE /)
DISK=/dev/$(basename "$ROOT_PART" | sed 's/p[0-9]*$//')
PART_NUM=$(basename "$ROOT_PART" | sed -n 's/.*p\([0-9]*\)/\1/p')
[[ -n "$PART_NUM" ]] || { echo "RK3308BS: cannot parse root partition $ROOT_PART"; exit 1; }
if command -v growpart >/dev/null 2>&1; then
	growpart "$DISK" "$PART_NUM" || parted -s "$DISK" resizepart "$PART_NUM" 100%
else
	parted -s "$DISK" resizepart "$PART_NUM" 100%
fi
resize2fs "$ROOT_PART"
touch "$MARKER"
echo "RK3308BS: rootfs grown to $(df -h / | awk 'NR==2{print $2}')"
EOF

cat >"$GROW_UNIT" <<'EOF'
[Unit]
Description=RK3308BS grow rootfs to fill eMMC
DefaultDependencies=no
After=local-fs.target
Before=armbian-firstrun.service
ConditionPathExists=!/root/.rk3308bs_rootfs_grown

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-grow-rootfs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat >"$WPA_CONF" <<EOF
country=${WIFI_COUNTRY}
ctrl_interface=/var/run/wpa_supplicant
update_config=0

network={
	ssid="${WIFI_SSID}"
	psk="${WIFI_PASSWORD}"
	key_mgmt=WPA-PSK
}
EOF

cat >"$NETDEV" <<'EOF'
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF

cat >"$WPA_UNIT" <<'EOF'
[Unit]
Description=WPA supplicant for wlan0 (RK3308BS)
DefaultDependencies=no
After=local-fs.target rk3308bs-wifi-modules.service
Before=armbian-firstrun.service network-pre.target systemd-networkd.service
Wants=rk3308bs-wifi-modules.service

[Service]
Type=simple
ExecStart=/sbin/wpa_supplicant -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf -i wlan0
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat >"$WANTS_DROPIN" <<'EOF'
[Unit]
Wants=rk3308bs-grow-rootfs.service rk3308bs-display-modules.service rk3308bs-wifi-modules.service wpa-wlan0.service
EOF

cat >"$RELEASE" <<EOF
RK3308BS_IMAGE=${IMAGE_TAG}
RK3308BS_USER=${USER_NAME}
RK3308BS_WIFI=${WIFI_SSID:-none}
RK3308BS_ROOTFS_GROW=oneshot
RK3308BS_LCD=480x272-rgb
EOF

cat >"$ISSUE" <<EOF
RK3308BS Armbian ${IMAGE_TAG}
LCD 480x272 | WiFi: ${WIFI_SSID:-off} | User: ${USER_NAME}
First boot grows rootfs to ~6GB eMMC
Verify: cat /etc/rk3308bs-release

EOF

echo "rk3308bs-${IMAGE_TAG}" >"$HOSTNAME"

for f in not_logged_in_yet serial-root-autologin.conf rk3308bs-release issue hostname \
	rk3308bs-grow-rootfs.sh rk3308bs-grow-rootfs.service wpa_supplicant-wlan0.conf \
	25-wlan0.network wpa-wlan0.service rk3308bs.conf; do
	[[ -f "$WORKDIR/$f" ]] && sed -i 's/\r$//' "$WORKDIR/$f"
done

CMD="$WORKDIR/debugfs.cmd"
cat >"$CMD" <<EOF
write $NO_RESIZE /root/.no_rootfs_resize
rm /root/.not_logged_in_yet
write $FIRSTBOOT /root/.not_logged_in_yet
rm /etc/rk3308bs-release
write $RELEASE /etc/rk3308bs-release
rm /etc/issue
write $ISSUE /etc/issue
rm /etc/hostname
write $HOSTNAME /etc/hostname
rm /etc/systemd/system/serial-getty@ttyS3.service.d/baud1500000.conf
mkdir /etc/systemd/system/serial-getty@ttyS3.service.d
write $SERIAL_GETTY /etc/systemd/system/serial-getty@ttyS3.service.d/autologin.conf
mkdir /usr/local/sbin
write $GROW_SH /usr/local/sbin/rk3308bs-grow-rootfs.sh
write $GROW_UNIT /etc/systemd/system/rk3308bs-grow-rootfs.service
mkdir /etc/wpa_supplicant
write $WPA_CONF /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
mkdir /etc/systemd/network
write $NETDEV /etc/systemd/network/25-wlan0.network
write $WPA_UNIT /etc/systemd/system/wpa-wlan0.service
mkdir /etc/systemd/system/multi-user.target.d
write $WANTS_DROPIN /etc/systemd/system/multi-user.target.d/rk3308bs.conf
unlink /etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service
cd /etc/systemd/system
symlink /dev/null armbian-resize-filesystem.service
quit
EOF

debugfs -w "$DST" -f "$CMD" 2>&1 | grep -vE 'already exists|File not found by ext2_lookup while looking up' || true
cp "$DST" "$OUT"
echo "Wrote $OUT (${IMAGE_TAG}: WiFi=${WIFI_SSID:-off})"

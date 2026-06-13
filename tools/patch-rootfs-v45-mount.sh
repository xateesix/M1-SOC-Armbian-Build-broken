#!/usr/bin/env bash
# v45 hybrid: loop mount + chroot credentials + baked /boot/system.cfg + stock Armbian resize.
# No debugfs set_inode_field (avoids ext4 inode corruption from v17-debugfs / v43).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
BOOT_DIR="$SCRIPT_DIR/userpatches-boot"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v45.img}"
IMAGE_TAG="${RK3308BS_IMAGE_TAG:-v45-systemcfg-chroot}"
HOOK_RESIZE="$SCRIPT_DIR/userpatches-chroot/25-rk3308bs-rockchip-resize.sh"
HOOK_PRECONF="$SCRIPT_DIR/userpatches-chroot/30-rk3308bs-preconfigure.sh"

[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG"; exit 1; }
[[ -f "$SRC" ]] || { echo "Missing rootfs: $SRC"; exit 1; }
[[ -f "$HOOK_RESIZE" ]] || { echo "Missing $HOOK_RESIZE"; exit 1; }
[[ -f "$HOOK_PRECONF" ]] || { echo "Missing $HOOK_PRECONF"; exit 1; }
[[ -d "$BOOT_DIR/scripts" ]] || { echo "Missing $BOOT_DIR/scripts"; exit 1; }

if ! sudo -n true 2>/dev/null; then
	echo "Need passwordless sudo for loop mount (run: sudo -v)"
	exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG"
USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
USER_NAME="${USER_NAME:-xateesix}"
USER_REALNAME="${USER_REALNAME:-$USER_NAME}"
LOCALE="${LOCALE:-en_US.UTF-8}"
TIMEZONE="${TIMEZONE:-America/Los_Angeles}"
WIFI_COUNTRY="${WIFI_COUNTRY:-US}"
SERIAL_GETTY="${SERIAL_GETTY:-ttyS3}"
SERIAL_BAUD="${SERIAL_BAUD:-1500000}"
HOSTNAME="rk3308bs-${IMAGE_TAG}"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/rk3308bs-v45.XXXXXX")"
MNT="$WORKDIR/mnt"
IMG="$WORKDIR/rootfs.img"

cleanup() {
	sudo umount "$MNT" 2>/dev/null || true
	rm -rf "$WORKDIR"
}
trap cleanup EXIT

cp "$SRC" "$IMG"
mkdir -p "$MNT"
sudo mount -o loop "$IMG" "$MNT"

run_chroot_hook() {
	local hook="$1"
	local name
	name="$(basename "$hook")"
	cp "$hook" "$MNT/tmp/$name"
	chmod +x "$MNT/tmp/$name"
	sudo chroot "$MNT" /bin/bash "/tmp/$name"
	sudo rm -f "$MNT/tmp/$name"
}

run_chroot_hook "$HOOK_RESIZE"

cp "$HOOK_PRECONF" "$MNT/tmp/rk3308bs-preconfigure.sh"
chmod +x "$MNT/tmp/rk3308bs-preconfigure.sh"
sudo chroot "$MNT" env \
	ROOT_PASSWORD="$ROOT_PASSWORD" \
	USER_NAME="$USER_NAME" \
	USER_PASSWORD="$USER_PASSWORD" \
	USER_REALNAME="$USER_REALNAME" \
	LOCALE="$LOCALE" \
	TIMEZONE="$TIMEZONE" \
	WIFI_SSID="" \
	WIFI_PASSWORD="" \
	/bin/bash /tmp/rk3308bs-preconfigure.sh
sudo rm -f "$MNT/tmp/rk3308bs-preconfigure.sh"

# --- /boot/system.cfg + scripts (BTT-style, populated from config.env) ---
sudo mkdir -p "$MNT/boot/scripts"
for script in rk3308bs_init.sh system_cfg.sh sync_wifi_from_cfg.sh; do
	cp "$BOOT_DIR/scripts/$script" "$MNT/boot/scripts/$script"
	sudo chmod +x "$MNT/boot/scripts/$script"
done

SYSTEM_CFG="$WORKDIR/system.cfg"
cat >"$SYSTEM_CFG" <<EOF
# RK3308BS — edit on PC, reboot to apply (see /boot/scripts/boot.log)
check_interval=30
wlan=wlan0
hostname='${HOSTNAME}'
TimeZone='${TIMEZONE}'
WIFI_SSID='${WIFI_SSID:-}'
WIFI_PASSWD='${WIFI_PASSWORD:-}'
WIFI_COUNTRY='${WIFI_COUNTRY}'
EOF
sudo cp "$SYSTEM_CFG" "$MNT/boot/system.cfg"
sudo chmod 644 "$MNT/boot/system.cfg"

# wpa_supplicant (also synced from system.cfg on boot via rk3308bs_init)
sudo mkdir -p "$MNT/etc/wpa_supplicant"
sudo tee "$MNT/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" >/dev/null <<EOF
country=${WIFI_COUNTRY}
ctrl_interface=/var/run/wpa_supplicant
update_config=0

network={
	ssid="${WIFI_SSID:-}"
	psk="${WIFI_PASSWORD:-}"
	key_mgmt=WPA-PSK
}
EOF
sudo chmod 600 "$MNT/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"

sudo tee "$MNT/etc/systemd/network/25-wlan0.network" >/dev/null <<'EOF'
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF

sudo tee "$MNT/etc/systemd/system/wpa-wlan0.service" >/dev/null <<'EOF'
[Unit]
Description=WPA supplicant for wlan0 (RK3308BS)
DefaultDependencies=no
After=local-fs.target rk3308bs-boot-config.service rk3308bs-wifi-modules.service
Before=network-pre.target systemd-networkd.service

[Service]
Type=simple
ExecStart=/sbin/wpa_supplicant -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf -i wlan0
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo tee "$MNT/etc/systemd/system/rk3308bs-boot-config.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS apply /boot/system.cfg (hostname, TZ, WiFi)
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target wpa-wlan0.service

[Service]
Type=oneshot
ExecStart=/bin/bash /boot/scripts/rk3308bs_init.sh
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

# --- keyboard / locale / autologin / firstrun off ---
sudo tee "$MNT/etc/default/keyboard" >/dev/null <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

sudo tee "$MNT/etc/default/console-setup" >/dev/null <<'EOF'
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Uni2"
FONTFACE="Fixed"
FONTSIZE="8x16"
VIDEOMODE=
EOF

sudo tee "$MNT/etc/issue" >/dev/null <<EOF
RK3308BS Armbian ${IMAGE_TAG}
Serial: auto-login ${USER_NAME} on ttyS3
Edit WiFi/host/TZ: /boot/system.cfg then reboot
Image: /etc/rk3308bs-release

EOF

sudo tee "$MNT/etc/rk3308bs-release" >/dev/null <<EOF
RK3308BS_IMAGE=${IMAGE_TAG}
RK3308BS_USER=${USER_NAME}
RK3308BS_WIFI=${WIFI_SSID:-none}
RK3308BS_LOCALE=${LOCALE}
RK3308BS_TZ=${TIMEZONE}
RK3308BS_ROOTFS_GROW=armbian-resize-filesystem
RK3308BS_LCD=480x272-rgb
RK3308BS_SYSTEM_CFG=/boot/system.cfg
EOF

echo "$HOSTNAME" | sudo tee "$MNT/etc/hostname" >/dev/null

sudo mkdir -p "$MNT/etc/systemd/system/serial-getty@ttyS3.service.d"
sudo tee "$MNT/etc/systemd/system/serial-getty@ttyS3.service.d/autologin.conf" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --keep-baud 115200,1500000,9600 --noclear %I \$TERM
Type=idle
EOF

sudo rm -f \
	"$MNT/etc/systemd/system/getty@.service.d/override.conf" \
	"$MNT/etc/systemd/system/serial-getty@.service.d/override.conf" \
	"$MNT/etc/systemd/system/serial-getty@.service.d/autologin.conf" \
	"$MNT/etc/systemd/system/serial-getty@ttyS3.service.d/baud1500000.conf" \
	"$MNT/etc/profile.d/armbian-check-first-login.sh" \
	"$MNT/etc/profile.d/armbian-check-first-login-reboot.sh" \
	"$MNT/root/.not_logged_in_yet" \
	"$MNT/root/.no_rootfs_resize"

sudo rm -f \
	"$MNT/etc/systemd/system/multi-user.target.wants/armbian-firstrun.service" \
	"$MNT/etc/systemd/system/multi-user.target.wants/armbian-firstlogin.service"

sudo ln -sf /dev/null "$MNT/etc/systemd/system/armbian-firstrun.service"
sudo ln -sf /dev/null "$MNT/etc/systemd/system/armbian-firstlogin.service"

# Enable stock Armbian resize + our boot-config / wpa (chroot systemctl)
sudo chroot "$MNT" systemctl enable armbian-resize-filesystem.service 2>/dev/null || true
sudo chroot "$MNT" systemctl enable rk3308bs-boot-config.service 2>/dev/null || true
sudo chroot "$MNT" systemctl enable wpa-wlan0.service 2>/dev/null || true

sudo chmod 644 "$MNT/etc/systemd/system/serial-getty@ttyS3.service.d/autologin.conf"
sudo chmod 644 "$MNT/etc/passwd" "$MNT/etc/group"
sudo chmod 640 "$MNT/etc/shadow" "$MNT/etc/gshadow"
sudo chown root:shadow "$MNT/etc/shadow" "$MNT/etc/gshadow" 2>/dev/null || true
sudo chown -R "${USER_NAME}:${USER_NAME}" "$MNT/home/${USER_NAME}"

sudo umount "$MNT"
cp "$IMG" "$OUT"
trap - EXIT
rm -rf "$WORKDIR"

echo "Wrote $OUT (${IMAGE_TAG}: chroot + system.cfg, armbian-resize enabled)"
bash "$SCRIPT_DIR/tools/verify-rootfs-password.sh" "$OUT" "$ROOT_PASSWORD" || true

echo "=== verify passwd/shadow inode modes (must NOT be 644 on dirs) ==="
debugfs -R "stat /etc/passwd" "$OUT" | grep -E "Inode:|Type:|Mode:"
debugfs -R "stat /etc/shadow" "$OUT" | grep -E "Inode:|Type:|Mode:"
debugfs -R "stat /home/${USER_NAME}" "$OUT" | grep -E "Inode:|Type:|Mode:" || true

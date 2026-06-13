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

if [[ $EUID -eq 0 ]]; then
	SUDO=""
elif sudo -n true 2>/dev/null; then
	SUDO="sudo"
else
	echo "Need root or passwordless sudo for loop mount (run: sudo -v, or: wsl -u root ...)"
	exit 1
fi

run_root() {
	if [[ -n "$SUDO" ]]; then
		sudo "$@"
	else
		"$@"
	fi
}

setup_cross_chroot() {
	[[ "$(uname -m)" == "aarch64" ]] && return 0
	local qemu_bin=""
	for candidate in \
		/usr/bin/qemu-aarch64-static \
		/usr/bin/qemu-aarch64 \
		/usr/libexec/qemu-binfmt/aarch64-binfmt; do
		[[ -x "$candidate" ]] && qemu_bin="$candidate" && break
	done
	if [[ -z "$qemu_bin" ]]; then
		echo "[rk3308bs] Installing qemu-user-hwe for ARM64 chroot ..."
		run_root apt-get update -qq
		run_root apt-get install -y -qq qemu-user-hwe qemu-user-binfmt-hwe || true
		for candidate in /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64; do
			[[ -x "$candidate" ]] && qemu_bin="$candidate" && break
		done
	fi
	[[ -n "$qemu_bin" ]] || { echo "No qemu-aarch64 binary found (install qemu-user-hwe)"; exit 1; }
	run_root mkdir -p "$MNT/usr/bin"
	run_root cp -f "$qemu_bin" "$MNT/usr/bin/qemu-aarch64-static"
}

teardown_cross_chroot() {
	rm -f "$MNT/usr/bin/qemu-aarch64-static"
}

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
	run_root umount "$MNT" 2>/dev/null || true
	rm -rf "$WORKDIR"
}
trap cleanup EXIT

cp "$SRC" "$IMG"
mkdir -p "$MNT"
run_root mount -o loop "$IMG" "$MNT"
setup_cross_chroot

run_chroot_hook() {
	local hook="$1"
	local name
	name="$(basename "$hook")"
	cp "$hook" "$MNT/tmp/$name"
	chmod +x "$MNT/tmp/$name"
	run_root chroot "$MNT" /bin/bash "/tmp/$name"
	run_root rm -f "$MNT/tmp/$name"
}

run_chroot_hook "$HOOK_RESIZE"

cp "$HOOK_PRECONF" "$MNT/tmp/rk3308bs-preconfigure.sh"
chmod +x "$MNT/tmp/rk3308bs-preconfigure.sh"
run_root chroot "$MNT" env \
	ROOT_PASSWORD="$ROOT_PASSWORD" \
	USER_NAME="$USER_NAME" \
	USER_PASSWORD="$USER_PASSWORD" \
	USER_REALNAME="$USER_REALNAME" \
	LOCALE="$LOCALE" \
	TIMEZONE="$TIMEZONE" \
	WIFI_SSID="" \
	WIFI_PASSWORD="" \
	/bin/bash /tmp/rk3308bs-preconfigure.sh
run_root rm -f "$MNT/tmp/rk3308bs-preconfigure.sh"

# --- /boot/system.cfg + scripts (BTT-style, populated from config.env) ---
run_root mkdir -p "$MNT/boot/scripts"
for script in rk3308bs_init.sh system_cfg.sh sync_wifi_from_cfg.sh; do
	cp "$BOOT_DIR/scripts/$script" "$MNT/boot/scripts/$script"
	run_root chmod +x "$MNT/boot/scripts/$script"
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
run_root cp "$SYSTEM_CFG" "$MNT/boot/system.cfg"
run_root chmod 644 "$MNT/boot/system.cfg"

# wpa_supplicant (also synced from system.cfg on boot via rk3308bs_init)
run_root mkdir -p "$MNT/etc/wpa_supplicant"
run_root tee "$MNT/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" >/dev/null <<EOF
country=${WIFI_COUNTRY}
ctrl_interface=/var/run/wpa_supplicant
update_config=0

network={
	ssid="${WIFI_SSID:-}"
	psk="${WIFI_PASSWORD:-}"
	key_mgmt=WPA-PSK
}
EOF
run_root chmod 600 "$MNT/etc/wpa_supplicant/wpa_supplicant-wlan0.conf"

run_root tee "$MNT/etc/systemd/network/25-wlan0.network" >/dev/null <<'EOF'
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF

run_root tee "$MNT/etc/systemd/system/wpa-wlan0.service" >/dev/null <<'EOF'
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

run_root tee "$MNT/etc/systemd/system/rk3308bs-boot-config.service" >/dev/null <<'EOF'
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
run_root tee "$MNT/etc/default/keyboard" >/dev/null <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

run_root tee "$MNT/etc/default/console-setup" >/dev/null <<'EOF'
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Uni2"
FONTFACE="Fixed"
FONTSIZE="8x16"
VIDEOMODE=
EOF

run_root tee "$MNT/etc/issue" >/dev/null <<EOF
RK3308BS Armbian ${IMAGE_TAG}
Serial: auto-login ${USER_NAME} on ${SERIAL_GETTY} @ ${SERIAL_BAUD}
Edit WiFi/host/TZ: /boot/system.cfg then reboot
Image: /etc/rk3308bs-release

EOF

run_root tee "$MNT/etc/rk3308bs-release" >/dev/null <<EOF
RK3308BS_IMAGE=${IMAGE_TAG}
RK3308BS_USER=${USER_NAME}
RK3308BS_WIFI=${WIFI_SSID:-none}
RK3308BS_LOCALE=${LOCALE}
RK3308BS_TZ=${TIMEZONE}
RK3308BS_ROOTFS_GROW=armbian-resize-filesystem
RK3308BS_LCD=480x272-rgb
RK3308BS_SYSTEM_CFG=/boot/system.cfg
EOF

echo "$HOSTNAME" | run_root tee "$MNT/etc/hostname" >/dev/null

bash "$SCRIPT_DIR/tools/_apply-serial-getty.sh" "$MNT" "$USER_NAME" "$SERIAL_GETTY" "$SERIAL_BAUD"

run_root rm -f \
	"$MNT/etc/systemd/system/getty@.service.d/override.conf" \
	"$MNT/etc/systemd/system/serial-getty@.service.d/override.conf" \
	"$MNT/etc/systemd/system/serial-getty@.service.d/autologin.conf" \
	"$MNT/etc/systemd/system/serial-getty@${SERIAL_GETTY}.service.d/baud1500000.conf" \
	"$MNT/etc/profile.d/armbian-check-first-login.sh" \
	"$MNT/etc/profile.d/armbian-check-first-login-reboot.sh" \
	"$MNT/root/.not_logged_in_yet" \
	"$MNT/root/.no_rootfs_resize"

run_root rm -f \
	"$MNT/etc/systemd/system/multi-user.target.wants/armbian-firstrun.service" \
	"$MNT/etc/systemd/system/multi-user.target.wants/armbian-firstlogin.service"

run_root ln -sf /dev/null "$MNT/etc/systemd/system/armbian-firstrun.service"
run_root ln -sf /dev/null "$MNT/etc/systemd/system/armbian-firstlogin.service"

run_root chroot "$MNT" systemctl enable armbian-resize-filesystem.service 2>/dev/null || true
run_root chroot "$MNT" systemctl enable rk3308bs-boot-config.service 2>/dev/null || true
run_root chroot "$MNT" systemctl enable wpa-wlan0.service 2>/dev/null || true

run_root chmod 644 "$MNT/etc/passwd" "$MNT/etc/group"
run_root chmod 640 "$MNT/etc/shadow" "$MNT/etc/gshadow"
run_root chroot "$MNT" chown root:shadow /etc/shadow /etc/gshadow 2>/dev/null || true
run_root chroot "$MNT" chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}" 2>/dev/null || true

teardown_cross_chroot
run_root umount "$MNT"
cp "$IMG" "$OUT"
trap - EXIT
rm -rf "$WORKDIR"

echo "Wrote $OUT (${IMAGE_TAG}: chroot + system.cfg, armbian-resize enabled)"
bash "$SCRIPT_DIR/tools/verify-rootfs-password.sh" "$OUT" "$ROOT_PASSWORD" || true

echo "=== verify passwd/shadow inode modes (must NOT be 644 on dirs) ==="
debugfs -R "stat /etc/passwd" "$OUT" | grep -E "Inode:|Type:|Mode:"
debugfs -R "stat /etc/shadow" "$OUT" | grep -E "Inode:|Type:|Mode:"
debugfs -R "stat /home/${USER_NAME}" "$OUT" | grep -E "Inode:|Type:|Mode:" || true

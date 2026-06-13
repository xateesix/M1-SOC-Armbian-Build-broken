#!/usr/bin/env bash
# Bake credentials/locale/autologin via loop mount + chroot (safe — no debugfs set_inode_field).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v20.img}"
IMAGE_TAG="${RK3308BS_IMAGE_TAG:-v20-serial-autologin}"
HOOK_LAYOUT="$SCRIPT_DIR/userpatches-chroot/25-rk3308bs-emmc-layout.sh"
HOOK_PRECONF="$SCRIPT_DIR/userpatches-chroot/30-rk3308bs-preconfigure.sh"

[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG"; exit 1; }
[[ -f "$SRC" ]] || { echo "Missing rootfs: $SRC"; exit 1; }
[[ -f "$HOOK_LAYOUT" ]] || { echo "Missing $HOOK_LAYOUT"; exit 1; }
[[ -f "$HOOK_PRECONF" ]] || { echo "Missing $HOOK_PRECONF"; exit 1; }

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

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/rk3308bs-rootfs.XXXXXX")"
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

run_chroot_hook "$HOOK_LAYOUT"

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

# US keyboard — no console-setup wizard
sudo tee "$MNT/etc/default/keyboard" >/dev/null <<'EOF'
# US English keyboard (baked at image build — no console-setup wizard)
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
Password login: ${USER_NAME} / ${USER_PASSWORD}
Locale: ${LOCALE} | TZ: ${TIMEZONE} | Keyboard: US
Image stamp: /etc/rk3308bs-release

EOF

sudo tee "$MNT/etc/rk3308bs-release" >/dev/null <<EOF
RK3308BS_IMAGE=${IMAGE_TAG}
RK3308BS_USER=${USER_NAME}
RK3308BS_SERIAL_AUTOLOGIN=${USER_NAME}
RK3308BS_LOCALE=${LOCALE}
RK3308BS_TZ=${TIMEZONE}
EOF

echo "rk3308bs-${IMAGE_TAG}" | sudo tee "$MNT/etc/hostname" >/dev/null

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
	"$MNT/root/.not_logged_in_yet"

sudo rm -f \
	"$MNT/etc/systemd/system/multi-user.target.wants/armbian-firstrun.service" \
	"$MNT/etc/systemd/system/multi-user.target.wants/armbian-firstlogin.service" \
	"$MNT/etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service"

sudo ln -sf /dev/null "$MNT/etc/systemd/system/armbian-firstrun.service"
sudo ln -sf /dev/null "$MNT/etc/systemd/system/armbian-firstlogin.service"
sudo ln -sf /dev/null "$MNT/etc/systemd/system/armbian-resize-filesystem.service"

sudo chmod 644 "$MNT/etc/systemd/system/serial-getty@ttyS3.service.d/autologin.conf"
sudo chmod 644 "$MNT/etc/passwd" "$MNT/etc/group"
sudo chmod 640 "$MNT/etc/shadow" "$MNT/etc/gshadow"
sudo chown root:shadow "$MNT/etc/shadow" "$MNT/etc/gshadow" 2>/dev/null || true
sudo chown -R "${USER_NAME}:${USER_NAME}" "$MNT/home/${USER_NAME}"

sudo umount "$MNT"
cp "$IMG" "$OUT"
trap - EXIT
rm -rf "$WORKDIR"

echo "Wrote $OUT (${IMAGE_TAG}: ${USER_NAME} autologin, chroot credentials — no debugfs inode edits)"
bash "$SCRIPT_DIR/tools/verify-rootfs-password.sh" "$OUT" "$ROOT_PASSWORD" || true

echo "=== verify passwd/shadow/home inode modes ==="
debugfs -R "stat /etc/passwd" "$OUT" | grep -E "Inode:|Type:|Mode:"
debugfs -R "stat /etc/shadow" "$OUT" | grep -E "Inode:|Type:|Mode:"
debugfs -R "stat /home/${USER_NAME}" "$OUT" | grep -E "Inode:|Type:|Mode:" || true

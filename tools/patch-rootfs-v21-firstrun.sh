#!/usr/bin/env bash
# Official Armbian first-boot preset (/root/.not_logged_in_yet) + serial root autologin for firstrun.
# Does NOT touch /etc/passwd, /etc/shadow, or /etc/group (debugfs set_inode_field corrupts them).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v21.img}"
IMAGE_TAG="${RK3308BS_IMAGE_TAG:-v21-armbian-firstrun}"

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

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DST="$WORKDIR/rootfs.img"
NO_RESIZE="$WORKDIR/no_rootfs_resize"
FIRSTBOOT="$WORKDIR/not_logged_in_yet"
SERIAL_GETTY="$WORKDIR/serial-root-autologin.conf"
RELEASE="$WORKDIR/rk3308bs-release"
ISSUE="$WORKDIR/issue"
HOSTNAME="$WORKDIR/hostname"

cp "$SRC" "$DST"
: >"$NO_RESIZE"

# https://docs.armbian.com/User-Guide_Autoconfig/
cat >"$FIRSTBOOT" <<EOF
# RK3308BS — Armbian official non-interactive first boot
PRESET_ROOT_PASSWORD="$ROOT_PASSWORD"
PRESET_USER_NAME="$USER_NAME"
PRESET_USER_PASSWORD="$USER_PASSWORD"
PRESET_DEFAULT_REALNAME="$USER_REALNAME"
PRESET_LOCALE="$LOCALE"
PRESET_TIMEZONE="$TIMEZONE"
SET_LANG_BASED_ON_LOCATION="n"
PRESET_CONNECT_WIRELESS="n"
PRESET_NET_CHANGE_DEFAULTS="0"
EOF

cat >"$SERIAL_GETTY" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --keep-baud 115200,1500000,9600 --noclear %I $TERM
Type=idle
EOF

cat >"$RELEASE" <<EOF
RK3308BS_IMAGE=${IMAGE_TAG}
RK3308BS_USER=${USER_NAME}
RK3308BS_FIRSTRUN=armbian-preset
EOF

cat >"$ISSUE" <<EOF
RK3308BS Armbian ${IMAGE_TAG}
First boot: root auto-login on serial (Armbian firstrun applies PRESET_*)
Then login as ${USER_NAME} / ${USER_PASSWORD}
Verify: cat /etc/rk3308bs-release

EOF

echo "rk3308bs-${IMAGE_TAG}" >"$HOSTNAME"

for f in not_logged_in_yet serial-root-autologin.conf rk3308bs-release issue hostname; do
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
unlink /etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service
cd /etc/systemd/system
symlink /dev/null armbian-resize-filesystem.service
quit
EOF

debugfs -w "$DST" -f "$CMD"

cp "$DST" "$OUT"
echo "Wrote $OUT (${IMAGE_TAG}: Armbian PRESET firstrun, serial root autologin, no passwd/shadow edits)"

echo "=== verify passwd/group inode modes ==="
debugfs -R "stat /etc/passwd" "$OUT" | grep -E "Inode:|Mode:"
debugfs -R "stat /etc/group" "$OUT" | grep -E "Inode:|Mode:"
debugfs -R "dump /root/.not_logged_in_yet $WORKDIR/verify-preset" "$OUT" >/dev/null
grep PRESET_USER_NAME "$WORKDIR/verify-preset"

#!/usr/bin/env bash
# Patch rootfs ext4 without sudo: no GPT resize + non-interactive Armbian first boot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v15.img}"

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

cp "$SRC" "$DST"
: >"$NO_RESIZE"

cat >"$FIRSTBOOT" <<EOF
# RK3308BS pre-baked first boot (no WiFi, no interactive wizard)
PRESET_ROOT_PASSWORD="$ROOT_PASSWORD"
PRESET_USER_NAME="$USER_NAME"
PRESET_USER_PASSWORD="$USER_PASSWORD"
PRESET_DEFAULT_REALNAME="$USER_REALNAME"
PRESET_LOCALE="$LOCALE"
PRESET_TIMEZONE="$TIMEZONE"
PRESET_CONNECT_WIRELESS=0
PRESET_NET_CHANGE_DEFAULTS=0
EOF

debugfs -w "$DST" <<EOF
write $NO_RESIZE /root/.no_rootfs_resize
rm /root/.not_logged_in_yet
write $FIRSTBOOT /root/.not_logged_in_yet
unlink /etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service
cd /etc/systemd/system
symlink /dev/null armbian-resize-filesystem.service
EOF

cp "$DST" "$OUT"
echo "Wrote $OUT (no resize, PRESET first-boot: user=${USER_NAME}, locale=${LOCALE}, tz=${TIMEZONE}, no WiFi)"

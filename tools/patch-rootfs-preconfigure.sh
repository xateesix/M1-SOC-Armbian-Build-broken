#!/usr/bin/env bash
# Patch an ext4 rootfs.img: locale, timezone, users, WiFi — no first-boot wizard.
# Run in WSL with sudo (loop mount + chroot).
#
# Usage:
#   ./tools/patch-rootfs-preconfigure.sh [input.img] [output.img]
#
# Defaults: rootfs-v11.img -> rootfs-v14.img (reads config.env)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v14.img}"
HOOK_LAYOUT="$SCRIPT_DIR/userpatches-chroot/25-rk3308bs-emmc-layout.sh"
HOOK_PRECONF="$SCRIPT_DIR/userpatches-chroot/30-rk3308bs-preconfigure.sh"

[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG"; exit 1; }
[[ -f "$SRC" ]] || { echo "Missing rootfs: $SRC"; exit 1; }
[[ -f "$HOOK_LAYOUT" ]] || { echo "Missing $HOOK_LAYOUT"; exit 1; }
[[ -f "$HOOK_PRECONF" ]] || { echo "Missing $HOOK_PRECONF"; exit 1; }

if ! sudo -n true 2>/dev/null; then
	echo "Need sudo for loop mount. Run: sudo -v"
	exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG"
export ROOT_PASSWORD USER_NAME USER_PASSWORD USER_REALNAME LOCALE TIMEZONE WIFI_SSID WIFI_PASSWORD
USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"

WORKDIR="$(mktemp -d)"
trap 'sudo umount "$MNT" 2>/dev/null || true; rm -rf "$WORKDIR"' EXIT

MNT="$WORKDIR/mnt"
IMG="$WORKDIR/rootfs.img"
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
	WIFI_SSID="$WIFI_SSID" \
	WIFI_PASSWORD="$WIFI_PASSWORD" \
	/bin/bash /tmp/rk3308bs-preconfigure.sh
sudo rm -f "$MNT/tmp/rk3308bs-preconfigure.sh"

sudo umount "$MNT"
cp "$IMG" "$OUT"
trap - EXIT
rm -rf "$WORKDIR"

echo "Wrote $OUT (locale=${LOCALE}, tz=${TIMEZONE}, user=${USER_NAME}, no resize, no first-boot wizard)"

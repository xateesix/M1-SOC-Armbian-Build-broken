#!/usr/bin/env bash
# Install 6.18.0-dirty kernel modules via loop mount + depmod (preferred).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC_ROOTFS="${1:-$REL/rootfs-v24-patched.img}"
OUT_ROOTFS="${2:-$REL/rootfs-v24.img}"
MOD_SRC="${3:-$REL/_modules_6.18.0-dirty}"

[[ -d "$MOD_SRC/lib/modules" ]] || { echo "Missing modules: $MOD_SRC"; exit 1; }
[[ -f "$SRC_ROOTFS" ]] || { echo "Missing rootfs: $SRC_ROOTFS"; exit 1; }

sudo_cmd() {
	if sudo -n true 2>/dev/null; then
		sudo "$@"
	elif [[ -f "$CONFIG" ]]; then
		# shellcheck source=/dev/null
		source "$CONFIG"
		if [[ -n "${SUDO_PASSWORD:-}" ]]; then
			echo "$SUDO_PASSWORD" | sudo -S "$@"
			return
		fi
	fi
	return 1
}

if ! sudo_cmd true; then
	echo "WARN: sudo unavailable  -  loop mount install skipped"
	exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'sudo_cmd umount "$MNT" 2>/dev/null || true; rm -rf "$WORKDIR"' EXIT

cp "$SRC_ROOTFS" "$WORKDIR/rootfs.img"
MNT="$WORKDIR/mnt"
mkdir -p "$MNT"
sudo_cmd mount -o loop "$WORKDIR/rootfs.img" "$MNT"

KVER="$(ls "$MOD_SRC/lib/modules")"
MOD_DEST="$MNT/usr/lib/modules/$KVER"
rm -rf "$MOD_DEST"
mkdir -p "$MNT/usr/lib/modules"
cp -a "$MOD_SRC/lib/modules/$KVER" "$MNT/usr/lib/modules/"

LOAD_SH="$MNT/usr/local/sbin/rk3308bs-load-wifi.sh"
mkdir -p "$MNT/usr/local/sbin"
cat >"$LOAD_SH" <<EOF
#!/bin/bash
set -euo pipefail
M=/usr/lib/modules/${KVER}/kernel
insmod "\$M/net/rfkill/rfkill.ko"
insmod "\$M/lib/crypto/libarc4.ko"
insmod "\$M/net/wireless/cfg80211.ko"
insmod "\$M/net/mac80211/mac80211.ko"
insmod "\$M/drivers/net/wireless/rtl8189fs/8189fs.ko"
EOF

cat >"$MNT/etc/systemd/system/rk3308bs-wifi-modules.service" <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target wpa-wlan0.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo_cmd depmod -b "$MNT" "$KVER"
sudo_cmd umount "$MNT"
cp "$WORKDIR/rootfs.img" "$OUT_ROOTFS"
trap - EXIT
rm -rf "$WORKDIR"
echo "Wrote $OUT_ROOTFS with full modules for $KVER + depmod"

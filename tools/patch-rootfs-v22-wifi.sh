#!/usr/bin/env bash
# Rootfs: WiFi + grow rootfs + networkd/wpa (no Armbian firstrun  -  credentials from v17 patch).
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

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/rk3308bs-wifi.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

DST="$WORKDIR/rootfs.img"
cp "$SRC" "$DST"

NO_RESIZE="$WORKDIR/no_rootfs_resize"
: >"$NO_RESIZE"
SERIAL_GETTY="$WORKDIR/serial-root-autologin.conf"
RELEASE="$WORKDIR/rk3308bs-release"
ISSUE="$WORKDIR/issue"
HOSTNAME="$WORKDIR/hostname"
GROW_SH="$WORKDIR/rk3308bs-grow-rootfs.sh"
GROW_UNIT="$WORKDIR/rk3308bs-grow-rootfs.service"
NETPLAN_CONF="$WORKDIR/01-rk3308bs-wlan0.yaml"
NETPLAN_UNIT="$WORKDIR/rk3308bs-networking.service"
NETPLAN_TIMER="$WORKDIR/rk3308bs-networking.timer"
WANTS_DROPIN="$WORKDIR/rk3308bs.conf"

cat >"$SERIAL_GETTY" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --keep-baud 115200,1500000,9600 --noclear %I \$TERM
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
# Repair any prior debugfs inode damage before expanding.
e2fsck -fy "$ROOT_PART" || { echo "RK3308BS: e2fsck failed on $ROOT_PART"; exit 1; }
if command -v growpart >/dev/null 2>&1; then
	growpart "$DISK" "$PART_NUM" || parted -s "$DISK" resizepart "$PART_NUM" 100%
else
	parted -s "$DISK" resizepart "$PART_NUM" 100%
fi
resize2fs "$ROOT_PART"
e2fsck -fy "$ROOT_PART" || true
touch "$MARKER"
echo "RK3308BS: rootfs grown to $(df -h / | awk 'NR==2{print $2}')"
EOF

cat >"$GROW_UNIT" <<'EOF'
[Unit]
Description=RK3308BS grow rootfs to fill eMMC
DefaultDependencies=no
After=local-fs.target
ConditionPathExists=!/root/.rk3308bs_rootfs_grown

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-grow-rootfs.sh
RemainAfterExit=yes
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

cat >"$NETPLAN_CONF" <<EOF
network:
  version: 2
  renderer: networkd
  wifis:
    wlan0:
      optional: true
      dhcp4: true
      access-points:
        "${WIFI_SSID}":
          password: "${WIFI_PASSWORD}"
EOF

cat >"$NETPLAN_UNIT" <<'EOF'
[Unit]
Description=Apply netplan for wlan0 (RK3308BS)
DefaultDependencies=no
After=local-fs.target rk3308bs-wifi-modules.service
Before=network-pre.target systemd-networkd.service

[Service]
Type=oneshot
ExecStart=/usr/bin/netplan apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat >"$NETPLAN_TIMER" <<'EOF'
[Unit]
Description=RK3308BS delayed netplan apply (after WiFi modules)

[Timer]
OnBootSec=25s
Unit=rk3308bs-networking.service

[Install]
WantedBy=timers.target
EOF

cat >"$WANTS_DROPIN" <<'EOF'
[Unit]
Wants=rk3308bs-grow-rootfs.service rk3308bs-wifi-modules.service
EOF

cat >"$RELEASE" <<EOF
RK3308BS_IMAGE=${IMAGE_TAG}
RK3308BS_USER=${USER_NAME}
RK3308BS_WIFI=${WIFI_SSID:-none}
RK3308BS_LOCALE=${LOCALE}
RK3308BS_TZ=${TIMEZONE}
RK3308BS_ROOTFS_GROW=oneshot
RK3308BS_LCD=480x272-rgb
EOF

cat >"$ISSUE" <<EOF
RK3308BS Armbian ${IMAGE_TAG}
User: ${USER_NAME} | WiFi: ${WIFI_SSID:-off} | TZ: ${TIMEZONE}
Locale: ${LOCALE} | Keyboard: US
Verify: cat /etc/rk3308bs-release

EOF

echo "rk3308bs-${IMAGE_TAG}" >"$HOSTNAME"

for f in serial-root-autologin.conf rk3308bs-release issue hostname \
rk3308bs-grow-rootfs.sh rk3308bs-grow-rootfs.service 01-rk3308bs-wlan0.yaml \
rk3308bs-networking.service rk3308bs-networking.timer rk3308bs.conf; do
	[[ -f "$WORKDIR/$f" ]] && sed -i 's/\r$//' "$WORKDIR/$f"
done

CMD="$WORKDIR/debugfs.cmd"
cat >"$CMD" <<EOF
write $NO_RESIZE /root/.no_rootfs_resize
rm /root/.not_logged_in_yet
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
mkdir /etc/netplan
write $NETPLAN_CONF /etc/netplan/01-rk3308bs-wlan0.yaml
write $NETPLAN_UNIT /etc/systemd/system/rk3308bs-networking.service
write $NETPLAN_TIMER /etc/systemd/system/rk3308bs-networking.timer
mkdir /etc/systemd/system/multi-user.target.d
write $WANTS_DROPIN /etc/systemd/system/multi-user.target.d/rk3308bs.conf
rm /etc/profile.d/armbian-check-first-login.sh
rm /etc/profile.d/armbian-check-first-login-reboot.sh
unlink /etc/systemd/system/multi-user.target.wants/armbian-firstrun.service
unlink /etc/systemd/system/multi-user.target.wants/armbian-firstlogin.service
unlink /etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service
cd /etc/systemd/system
symlink /dev/null armbian-firstrun.service
symlink /dev/null armbian-firstlogin.service
symlink /dev/null armbian-resize-filesystem.service
mkdir /etc/systemd/system/timers.target.wants
ln /etc/systemd/system/rk3308bs-networking.timer /etc/systemd/system/timers.target.wants/rk3308bs-networking.timer
quit
EOF

debugfs -w "$DST" -f "$CMD" 2>&1 | grep -vE 'already exists|File not found by ext2_lookup while looking up' || true
cp "$DST" "$OUT"
echo "Wrote $OUT (${IMAGE_TAG}: WiFi=${WIFI_SSID:-off})"

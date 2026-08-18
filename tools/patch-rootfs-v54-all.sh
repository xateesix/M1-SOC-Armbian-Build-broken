#!/usr/bin/env bash
# v54 rootfs: v52 console + netplan networking + first-boot growpart/resize2fs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$SCRIPT_DIR/releases/1.0.0/rootfs-v52.img}"
OUT="${2:-$SCRIPT_DIR/releases/1.0.0/rootfs-v54.img}"
cp -f "$SRC" "$OUT"
debugfs -w -R 'rm /etc/systemd/system/rk3308bs-wifi-modules.service' "$OUT" 2>/dev/null || true
debugfs -w -R 'rm /etc/systemd/system/multi-user.target.wants/rk3308bs-wifi-modules.service' "$OUT" 2>/dev/null || true
MNT=$(mktemp -d)
cleanup() { umount "$MNT" 2>/dev/null || true; rm -rf "$MNT"; }
trap cleanup EXIT
mount -o loop "$OUT" "$MNT"

tee "$MNT/usr/local/sbin/rk3308bs-grow-rootfs.sh" >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
MARKER=/root/.rk3308bs_rootfs_grown
[[ -f "$MARKER" ]] && exit 0
ROOT_PART=$(findmnt -n -o SOURCE /)
DISK=/dev/$(basename "$ROOT_PART" | sed 's/p[0-9]*$//')
PART_NUM=$(basename "$ROOT_PART" | sed -n 's/.*p\([0-9]*\)/\1/p')
[[ -n "$PART_NUM" ]] || exit 1
SIZE_MB=$(df -m / | awk 'NR==2{print $2}')
[[ "$SIZE_MB" -ge 6000 ]] && { touch "$MARKER"; exit 0; }
e2fsck -fy "$ROOT_PART" || true
if command -v growpart >/dev/null 2>&1; then
  growpart "$DISK" "$PART_NUM" || parted -s "$DISK" resizepart "$PART_NUM" 99%
else
  parted -s "$DISK" resizepart "$PART_NUM" 99%
fi
resize2fs "$ROOT_PART"
touch "$MARKER"
echo "RK3308BS: rootfs grown to $(df -h / | awk 'NR==2{print $2}')" >/dev/kmsg
EOF
chmod 755 "$MNT/usr/local/sbin/rk3308bs-grow-rootfs.sh"

tee "$MNT/etc/systemd/system/rk3308bs-grow-rootfs.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS grow rootfs partition to fill eMMC
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target basic.target
ConditionPathExists=!/root/.rk3308bs_rootfs_grown

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-grow-rootfs.sh
RemainAfterExit=yes
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

tee "$MNT/etc/systemd/system/rk3308bs-wifi-modules.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules before networking
DefaultDependencies=no
After=local-fs.target rk3308bs-grow-rootfs.service
Before=network-pre.target systemd-networkd.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

tee "$MNT/etc/systemd/system/rk3308bs-networking.service" >/dev/null <<'EOF'
[Unit]
Description=Apply netplan for wlan0 (RK3308BS)
DefaultDependencies=no
After=rk3308bs-boot-config.service rk3308bs-wifi-modules.service
Before=network-pre.target systemd-networkd.service
ConditionPathExists=/sys/class/net/wlan0

[Service]
Type=oneshot
ExecStart=/usr/bin/netplan apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$MNT/etc/systemd/system/rk3308bs-grow-rootfs.service" \
  "$MNT/etc/systemd/system/rk3308bs-wifi-modules.service" \
  "$MNT/etc/systemd/system/rk3308bs-networking.service"

mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf ../rk3308bs-grow-rootfs.service "$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-grow-rootfs.service"
ln -sf ../rk3308bs-wifi-modules.service "$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-wifi-modules.service"
ln -sf ../rk3308bs-networking.service "$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-networking.service"

chroot "$MNT" systemctl mask armbian-resize-filesystem.service 2>/dev/null || true
chroot "$MNT" systemctl enable rk3308bs-networking.service 2>/dev/null || true
rm -f "$MNT/root/.no_rootfs_resize"

umount "$MNT"
trap - EXIT
echo "Wrote $OUT"

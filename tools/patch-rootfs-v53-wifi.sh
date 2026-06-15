#!/usr/bin/env bash
# Fix corrupt wifi-modules unit + single wpa supplicant (v53).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$SCRIPT_DIR/releases/1.0.0/rootfs-v52.img}"
OUT="${2:-$SCRIPT_DIR/releases/1.0.0/rootfs-v53.img}"
cp "$SRC" "$OUT"
MNT=$(mktemp -d)
cleanup() { umount "$MNT" 2>/dev/null || true; rm -rf "$MNT"; }
trap cleanup EXIT
mount -o loop "$OUT" "$MNT"

tee "$MNT/etc/systemd/system/rk3308bs-wifi-modules.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules
DefaultDependencies=no
After=local-fs.target basic.target
Before=network-pre.target wpa-wlan0.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

tee "$MNT/etc/systemd/system/wpa-wlan0.service" >/dev/null <<'EOF'
[Unit]
Description=WPA supplicant for wlan0 (RK3308BS)
DefaultDependencies=no
After=local-fs.target rk3308bs-boot-config.service rk3308bs-wifi-modules.service
Before=network-pre.target
ConditionPathExists=/sys/class/net/wlan0

[Service]
Type=simple
ExecStart=/sbin/wpa_supplicant -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf -i wlan0
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$MNT/etc/systemd/system/rk3308bs-wifi-modules.service" \
  "$MNT/etc/systemd/system/wpa-wlan0.service"

mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf ../rk3308bs-wifi-modules.service "$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-wifi-modules.service"
ln -sf ../wpa-wlan0.service "$MNT/etc/systemd/system/multi-user.target.wants/wpa-wlan0.service"

chroot "$MNT" systemctl disable wpa_supplicant.service 2>/dev/null || true
chroot "$MNT" systemctl mask wpa_supplicant.service 2>/dev/null || true
chroot "$MNT" systemctl enable rk3308bs-wifi-modules.service wpa-wlan0.service 2>/dev/null || true

umount "$MNT"
trap - EXIT
echo "Wrote $OUT"

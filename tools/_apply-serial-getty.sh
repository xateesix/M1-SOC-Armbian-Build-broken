#!/usr/bin/env bash
# Apply serial console getty inside a mounted rootfs (called from patch-rootfs-*-mount.sh).
# Armbian 6.18: ttyS3 @ 1500000 on UART3 (0xff0d0000) — same header as factory ttyFIQ0.
set -euo pipefail

MNT="${1:?mount point}"
USER_NAME="${2:?username}"
SERIAL_GETTY="${3:-ttyS3}"
SERIAL_BAUD="${4:-1500000}"

# Disable factory fiq-debugger getty (no fiq driver in 6.18).
sudo chroot "$MNT" systemctl disable serial-getty@ttyFIQ0.service 2>/dev/null || true
sudo rm -f "$MNT/etc/systemd/system/getty.target.wants/serial-getty@ttyFIQ0.service"

sudo mkdir -p "$MNT/etc/systemd/system/serial-getty@${SERIAL_GETTY}.service.d"
sudo tee "$MNT/etc/systemd/system/serial-getty@${SERIAL_GETTY}.service.d/autologin.conf" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --keep-baud 115200,${SERIAL_BAUD},9600 --noclear %I \$TERM
Type=idle
EOF

sudo rm -f \
	"$MNT/etc/systemd/system/getty@.service.d/override.conf" \
	"$MNT/etc/systemd/system/serial-getty@.service.d/override.conf" \
	"$MNT/etc/systemd/system/serial-getty@.service.d/autologin.conf" \
	"$MNT/etc/systemd/system/serial-getty@${SERIAL_GETTY}.service.d/baud1500000.conf"

# Allow root/user login on serial (Armbian may only list ttyFIQ0).
if [[ -f "$MNT/etc/securetty" ]] && ! grep -qx "$SERIAL_GETTY" "$MNT/etc/securetty"; then
	echo "$SERIAL_GETTY" | sudo tee -a "$MNT/etc/securetty" >/dev/null
fi

sudo chroot "$MNT" systemctl enable "serial-getty@${SERIAL_GETTY}.service" 2>/dev/null || true
sudo chmod 644 "$MNT/etc/systemd/system/serial-getty@${SERIAL_GETTY}.service.d/autologin.conf"

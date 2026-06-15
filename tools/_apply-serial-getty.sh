#!/usr/bin/env bash
# Apply serial console getty inside a mounted rootfs (called from patch-rootfs-*-mount.sh).
# RK3308BS: UART3 header @ 1500000 — console device is ttyFIQ0 (factory fiq-debugger).
set -euo pipefail

MNT="${1:?mount point}"
USER_NAME="${2:?username}"
SERIAL_GETTY="${3:-ttyFIQ0}"
SERIAL_BAUD="${4:-1500000}"

# Disable the alternate serial getty so only one console is active.
for alt in ttyFIQ0 ttyS3; do
	if [[ "$alt" != "$SERIAL_GETTY" ]]; then
		sudo chroot "$MNT" systemctl disable "serial-getty@${alt}.service" 2>/dev/null || true
		sudo rm -f "$MNT/etc/systemd/system/getty.target.wants/serial-getty@${alt}.service"
		sudo rm -rf "$MNT/etc/systemd/system/serial-getty@${alt}.service.d"
	fi
done

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

if [[ -f "$MNT/etc/securetty" ]] && ! grep -qx "$SERIAL_GETTY" "$MNT/etc/securetty"; then
	echo "$SERIAL_GETTY" | sudo tee -a "$MNT/etc/securetty" >/dev/null
fi

sudo chroot "$MNT" systemctl enable "serial-getty@${SERIAL_GETTY}.service" 2>/dev/null || true
sudo chmod 644 "$MNT/etc/systemd/system/serial-getty@${SERIAL_GETTY}.service.d/autologin.conf"

#!/usr/bin/env bash
# Patch an ext4 rootfs.img in-place for factory-DTB serial console (ttyFIQ0 @ 1500000).
# Run in WSL with sudo.
set -euo pipefail

ROOTFS="${1:?usage: patch-rootfs-serial-console.sh rootfs.img [console]}"
CONSOLE="${2:-ttyFIQ0}"

if ! sudo -n true 2>/dev/null; then
    echo "Need sudo for loop mount"
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'sudo umount "$MNT" 2>/dev/null || true; rm -rf "$WORKDIR"' EXIT

MNT="$WORKDIR/mnt"
mkdir -p "$MNT"
sudo mount -o loop "$ROOTFS" "$MNT"

mkdir -p "$MNT/etc/systemd/system/serial-getty@ttyFIQ0.service.d"
cat >"$MNT/etc/systemd/system/serial-getty@ttyFIQ0.service.d/baud1500000.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,57600,38400,9600 - 1500000 $TERM
EOF

if [[ "$CONSOLE" == "ttyFIQ0" ]]; then
    sudo chroot "$MNT" systemctl enable serial-getty@ttyFIQ0.service 2>/dev/null || true
    sudo chroot "$MNT" systemctl disable serial-getty@ttyS3.service 2>/dev/null || true
else
    sudo chroot "$MNT" systemctl enable serial-getty@ttyS3.service 2>/dev/null || true
    sudo chroot "$MNT" systemctl disable serial-getty@ttyFIQ0.service 2>/dev/null || true
fi

sudo umount "$MNT"
trap - EXIT
rm -rf "$WORKDIR"
echo "Patched $ROOTFS for console=$CONSOLE"

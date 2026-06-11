#!/usr/bin/env bash
# Patch ext4 rootfs.img for serial console without loop mount (uses debugfs).
# debugfs write syntax: write <host_source_file> <image_destination_path>
set -euo pipefail

ROOTFS="${1:?usage: patch-rootfs-serial-console-debugfs.sh rootfs.img [console]}"
CONSOLE="${2:-ttyFIQ0}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

CONF="$WORKDIR/baud1500000.conf"
cat >"$CONF" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,57600,38400,9600 - 1500000 $TERM
EOF

debugfs -w "$ROOTFS" <<EOF
mkdir /etc/systemd/system/serial-getty@ttyFIQ0.service.d
write $CONF /etc/systemd/system/serial-getty@ttyFIQ0.service.d/baud1500000.conf
unlink /etc/systemd/system/getty.target.wants/serial-getty@ttyS3.service
unlink /etc/systemd/system/getty.target.wants/serial-getty@ttyFIQ0.service
EOF

if [[ "$CONSOLE" == "ttyFIQ0" ]]; then
    debugfs -w "$ROOTFS" <<'EOF'
symlink /lib/systemd/system/serial-getty@.service /etc/systemd/system/getty.target.wants/serial-getty@ttyFIQ0.service
EOF
else
    debugfs -w "$ROOTFS" <<'EOF'
symlink /lib/systemd/system/serial-getty@.service /etc/systemd/system/getty.target.wants/serial-getty@ttyS3.service
EOF
fi

echo "Patched $ROOTFS for console=$CONSOLE (debugfs)"

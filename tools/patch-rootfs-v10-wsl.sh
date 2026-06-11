#!/usr/bin/env bash
set -euo pipefail
SRC="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0/rootfs.img"
OUT="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0/rootfs-v10.img"
DST="/tmp/rootfs-v10.img"
CONF=/tmp/baud1500000.conf

cp "$SRC" "$DST"
cat >"$CONF" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,57600,38400,9600 - 1500000 $TERM
EOF

debugfs -w "$DST" <<EOF
mkdir /etc/systemd/system/serial-getty@ttyFIQ0.service.d
write $CONF /etc/systemd/system/serial-getty@ttyFIQ0.service.d/baud1500000.conf
unlink /etc/systemd/system/getty.target.wants/serial-getty@ttyS3.service
cd /etc/systemd/system/getty.target.wants
symlink serial-getty@ttyFIQ0.service /lib/systemd/system/serial-getty@.service
EOF

debugfs -R "cat /etc/systemd/system/serial-getty@ttyFIQ0.service.d/baud1500000.conf" "$DST"
debugfs -R "ls -l /etc/systemd/system/getty.target.wants" "$DST"
cp "$DST" "$OUT"
echo "Wrote $OUT"

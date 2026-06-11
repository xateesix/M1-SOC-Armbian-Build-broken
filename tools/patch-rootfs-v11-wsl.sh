#!/usr/bin/env bash
# Revert/patch rootfs for ttyS3 @ 1500000 (Armbian 6.18 — no fiq-debugger).
set -euo pipefail
SRC="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0/rootfs.img"
OUT="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0/rootfs-v11.img"
DST="/tmp/rootfs-v11.img"
CONF=/tmp/baud1500000-s3.conf

cp "$SRC" "$DST"
cat >"$CONF" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --keep-baud 115200,1500000,9600 %I $TERM
EOF

debugfs -w "$DST" <<EOF
mkdir /etc/systemd/system/serial-getty@ttyS3.service.d
write $CONF /etc/systemd/system/serial-getty@ttyS3.service.d/baud1500000.conf
unlink /etc/systemd/system/getty.target.wants/serial-getty@ttyFIQ0.service
cd /etc/systemd/system/getty.target.wants
symlink serial-getty@ttyS3.service /lib/systemd/system/serial-getty@.service
EOF

debugfs -R "ls -l /etc/systemd/system/getty.target.wants" "$DST"
cp "$DST" "$OUT"
echo "Wrote $OUT"

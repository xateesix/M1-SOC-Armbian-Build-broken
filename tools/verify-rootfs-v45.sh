#!/usr/bin/env bash
set -euo pipefail
IMG="${1:-/mnt/c/Workspaces/Armbian-M1-SOC/releases/1.0.0/rootfs-v45.img}"
MNT="$(mktemp -d)"
LOOP="$(losetup -f --show -P "$IMG")"
cleanup() { umount "$MNT" 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT
mount "${LOOP}p1" "$MNT" 2>/dev/null || mount "$LOOP" "$MNT"
echo "=== rk3308bs-release ==="
cat "$MNT/etc/rk3308bs-release" 2>/dev/null || echo missing
echo "=== serial getty ttyFIQ0 ==="
ls -la "$MNT/etc/systemd/system/serial-getty@ttyFIQ0.service.d/" 2>/dev/null || echo missing
echo "=== serial getty ttyS3 (should be absent) ==="
ls -la "$MNT/etc/systemd/system/serial-getty@ttyS3.service.d/" 2>/dev/null || echo absent
echo "=== securetty ==="
grep -E 'ttyFIQ0|ttyS3' "$MNT/etc/securetty" 2>/dev/null || true
echo "=== system.cfg ==="
head -8 "$MNT/boot/system.cfg" 2>/dev/null || true

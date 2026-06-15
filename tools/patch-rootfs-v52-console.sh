#!/usr/bin/env bash
# Repatch rootfs: ttyS3 getty + multi-user default (no ttyFIQ0 wait).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$SCRIPT_DIR/releases/1.0.0/rootfs-v45.img}"
OUT="${2:-$SCRIPT_DIR/releases/1.0.0/rootfs-v52.img}"
SERIAL_GETTY=ttyS3 IMAGE_TAG=v52-ttyS3 \
  bash "$SCRIPT_DIR/tools/patch-rootfs-v45-mount.sh" "$SRC" "$OUT"
MNT_WORK=$(mktemp -d)
cleanup() { sudo umount "$MNT_WORK" 2>/dev/null || true; rm -rf "$MNT_WORK"; }
trap cleanup EXIT
sudo mkdir -p "$MNT_WORK"
sudo mount -o loop "$OUT" "$MNT_WORK"
sudo ln -sf /lib/systemd/system/multi-user.target "$MNT_WORK/etc/systemd/system/default.target"
# Broken copies (not symlinks) in wants/ confuse systemd — remove.
sudo rm -f "$MNT_WORK/etc/systemd/system/timers.target.wants/rk3308bs-display-modules.timer"
sudo rm -f "$MNT_WORK/etc/systemd/system/multi-user.target.wants/rk3308bs-wifi-modules.service"
sudo chmod 644 "$MNT_WORK/etc/systemd/system/rk3308bs-wifi-modules.service" 2>/dev/null || true
sudo umount "$MNT_WORK"
echo "Wrote $OUT (ttyS3 getty, multi-user.target)"

#!/usr/bin/env bash
# v55 rootfs: fix fs metadata, grow script (no mounted e2fsck), initramfs hook, fstab, armbianEnv.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$SCRIPT_DIR/releases/1.0.0/rootfs-v54.img}"
OUT="${2:-$SCRIPT_DIR/releases/1.0.0/rootfs-v55.img}"
cp -f "$SRC" "$OUT"
e2fsck -fy "$OUT" || true
MNT=$(mktemp -d)
cleanup() { umount "$MNT" 2>/dev/null || true; rm -rf "$MNT"; }
trap cleanup EXIT
mount -o loop "$OUT" "$MNT"

tee "$MNT/usr/local/sbin/rk3308bs-grow-rootfs.sh" >/dev/null <<'GROW'
#!/bin/bash
set -euo pipefail
MARKER=/root/.rk3308bs_rootfs_grown
log() { echo "RK3308BS-GROW: $*" >/dev/kmsg; }
[[ -f "$MARKER" ]] && exit 0
ROOT_PART=$(findmnt -n -o SOURCE /)
DISK=/dev/$(basename "$ROOT_PART" | sed 's/p[0-9]*$//')
PART_NUM=$(basename "$ROOT_PART" | sed -n 's/.*p\([0-9]*\)/\1/p')
[[ -n "$PART_NUM" ]] || { log "cannot parse $ROOT_PART"; exit 1; }
SIZE_MB=$(df -m / | awk 'NR==2{print $2}')
[[ "$SIZE_MB" -ge 6000 ]] && { log "already ${SIZE_MB}MB"; touch "$MARKER"; exit 0; }
log "growing $DISK p$PART_NUM from ${SIZE_MB}MB"
if command -v growpart >/dev/null 2>&1; then
  growpart "$DISK" "$PART_NUM" || parted -s "$DISK" resizepart "$PART_NUM" 99%
else
  parted -s "$DISK" resizepart "$PART_NUM" 99%
fi
partprobe "$DISK" 2>/dev/null || true
udevadm settle 2>/dev/null || true
resize2fs -f "$ROOT_PART"
touch "$MARKER"
log "done: $(df -h / | awk 'NR==2{print $2}')"
GROW
chmod 755 "$MNT/usr/local/sbin/rk3308bs-grow-rootfs.sh"

mkdir -p "$MNT/etc/initramfs-tools/scripts/local-premount"
tee "$MNT/etc/initramfs-tools/scripts/local-premount/rk3308bs-resize" >/dev/null <<'INITRD'
#!/bin/sh
PREREQ=""
prereqs() { echo "$PREREQ"; }
case "$1" in prereqs) prereqs; exit 0 ;; esac
. /scripts/functions
[ -z "${ROOT}" ] && exit 0
ROOTDEV=$(resolve_device "${ROOT}")
[ -z "${ROOTDEV}" ] && exit 0
FS_TYPE=$(blkid -o value -s TYPE "${ROOTDEV}" 2>/dev/null)
[ "${FS_TYPE}" = "ext4" ] || exit 0
log_begin_msg "RK3308BS: fsck and grow rootfs on ${ROOTDEV}"
e2fsck -fy "${ROOTDEV}" || true
resize2fs -f "${ROOTDEV}" 2>/dev/null || resize2fs "${ROOTDEV}" || true
log_end_msg
exit 0
INITRD
chmod 755 "$MNT/etc/initramfs-tools/scripts/local-premount/rk3308bs-resize"

sed -i '1s|.*|PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 / ext4 defaults,commit=120,errors=remount-ro 0 1|' "$MNT/etc/fstab"
sed -i 's|^rootdev=.*|rootdev=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9|' "$MNT/boot/armbianEnv.txt"

rm -f "$MNT/root/.rk3308bs_rootfs_grown"
chroot "$MNT" update-initramfs -u -k all 2>/dev/null || true

umount "$MNT"
trap - EXIT
e2fsck -fy "$OUT" || true
echo "Wrote $OUT"

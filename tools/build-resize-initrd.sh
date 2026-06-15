#!/usr/bin/env bash
# Build minimal aarch64 initrd: offline e2fsck + resize2fs on mmcblk0p6, then reboot.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS="${1:-$SCRIPT_DIR/releases/1.0.0/rootfs-v54.img}"
OUT="${2:-$SCRIPT_DIR/releases/1.0.0/_resize-initrd.cpio.gz}"
DIR=$(mktemp -d)
MNT=$(mktemp -d)
trap 'umount "$MNT" 2>/dev/null || true; rm -rf "$DIR" "$MNT"' EXIT
mount -o loop "$ROOTFS" "$MNT"

install -d "$DIR"/{bin,sbin,dev,proc,sys,lib/aarch64-linux-gnu,usr/lib/aarch64-linux-gnu,etc}
cat > "$DIR/init" <<'INIT'
#!/bin/sh
export PATH=/sbin:/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
ROOT=/dev/mmcblk0p6
echo "RK3308BS-RESIZE: fsck $ROOT" > /dev/kmsg
/sbin/e2fsck -fy "$ROOT" || true
echo "RK3308BS-RESIZE: resize2fs $ROOT" > /dev/kmsg
/sbin/resize2fs -f "$ROOT" || /sbin/resize2fs "$ROOT"
sync
echo "RK3308BS-RESIZE: reboot" > /dev/kmsg
exec /sbin/reboot -f
INIT
chmod 755 "$DIR/init"

copy_with_libs() {
  local src="$1" dst="$2"
  install -D "$src" "$DIR$dst"
  ldd "$src" 2>/dev/null | awk '/=> \// {print $3}' | sort -u | while read -r lib; do
    install -D "$lib" "$DIR$lib"
  done
}

for bin in /sbin/e2fsck /sbin/resize2fs /sbin/reboot /usr/bin/mount /usr/bin/umount /bin/sh; do
  copy_with_libs "$MNT$bin" "$bin"
done

( cd "$DIR" && find . -print0 | cpio --null -o -H newc | gzip -9 ) > "$OUT"
echo "Wrote $OUT ($(wc -c < "$OUT") bytes)"

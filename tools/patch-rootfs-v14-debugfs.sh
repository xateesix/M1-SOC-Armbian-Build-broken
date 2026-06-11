#!/usr/bin/env bash
# Patch rootfs ext4 without sudo: disable Armbian GPT resize (fixed Rockchip eMMC layout).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v14.img}"

[[ -f "$SRC" ]] || { echo "Missing rootfs: $SRC"; exit 1; }
command -v debugfs >/dev/null || { echo "Install e2fsprogs (debugfs)"; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DST="$WORKDIR/rootfs.img"
NO_RESIZE="$WORKDIR/no_rootfs_resize"

cp "$SRC" "$DST"
: >"$NO_RESIZE"

debugfs -w "$DST" <<EOF
write $NO_RESIZE /root/.no_rootfs_resize
unlink /etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service
cd /etc/systemd/system
symlink /dev/null armbian-resize-filesystem.service
EOF

cp "$DST" "$OUT"
echo "Wrote $OUT (/root/.no_rootfs_resize + masked armbian-resize-filesystem)"

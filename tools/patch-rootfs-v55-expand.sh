#!/usr/bin/env bash
# v55: offline expand ext4 rootfs image to TARGET_BYTES (default ~6.35GiB).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
SRC="${1:-$REL/rootfs-growfix.img}"
OUT="${2:-$REL/rootfs-expanded.img}"
TARGET_BYTES="${TARGET_BYTES:-6815744000}"

[[ -f "$SRC" ]] || { echo "Missing rootfs: $SRC"; exit 1; }

cp -f "$SRC" "$OUT"
e2fsck -fy "$OUT" || true

cur_size=$(stat -c%s "$OUT")
if (( cur_size < TARGET_BYTES )); then
	echo "Expanding image ${cur_size} -> ${TARGET_BYTES} bytes"
	truncate -s "$TARGET_BYTES" "$OUT"
fi

resize2fs -f "$OUT"
e2fsck -fy "$OUT" || true
echo "Wrote $OUT ($(stat -c%s "$OUT") bytes)"

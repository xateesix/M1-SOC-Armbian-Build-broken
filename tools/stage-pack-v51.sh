#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
FAC="$SCRIPT_DIR/factory_fresh/03_partitions"
PACK="$REL/pack_input_v51"
IMG="$PACK/Image"
ROOTFS="${1:-$REL/rootfs-v45.img}"
[[ -f "$ROOTFS" ]] || { echo "Missing $ROOTFS"; exit 1; }
[[ -f "$REL/_boot-v51.img" ]] || { echo "Missing _boot-v51.img"; exit 1; }
rm -rf "$PACK"
mkdir -p "$IMG"
cp "$FAC/package-file" "$PACK/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$IMG/"
cp "$REL/_uboot-memlayout.img" "$IMG/uboot.img"
cp "$REL/_boot-v51.img" "$IMG/boot.img"
cp "$ROOTFS" "$IMG/rootfs.img"
python3 "$SCRIPT_DIR/tools/patch-parameter-boot-size.py" \
	"$FAC/parameter.txt" "$IMG/boot.img" "$IMG/parameter.txt" \
	--rootfs "$IMG/rootfs.img"
echo "Staged $PACK"

#!/usr/bin/env bash
set -euo pipefail
REL="$PROJECT_ROOT/output/releases/1.0.0"
FAC="$PROJECT_ROOT/output/factory_fresh/03_partitions"
PACK="$REL/pack_input_v14"
IMG="$PACK/Image"
ROOTFS="${1:-$REL/rootfs-v14.img}"

if [ ! -f "$ROOTFS" ]; then
  ROOTFS="$REL/rootfs-v11.img"
fi

rm -rf "$PACK"
mkdir -p "$IMG"
cp "$REL/pack_input/package-file" "$PACK/"
cp "$REL/pack_input/Image/parameter.txt" "$IMG/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$IMG/"
cp "$REL/_uboot-memlayout.img" "$IMG/uboot.img"
cp "$REL/_boot-v14.img" "$IMG/boot.img"
cp "$ROOTFS" "$IMG/rootfs.img"
echo "Staged $PACK (rootfs=$(basename "$ROOTFS"))"

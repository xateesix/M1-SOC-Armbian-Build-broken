#!/usr/bin/env bash
set -euo pipefail
REL="$PROJECT_ROOT/output/releases/1.0.0"
FAC="$PROJECT_ROOT/output/factory_fresh/03_partitions"
PACK="$REL/pack_input_v16"
IMG="$PACK/Image"
ROOTFS="${1:-$REL/rootfs-v16.img}"

[[ -f "$ROOTFS" ]] || { echo "Missing $ROOTFS"; exit 1; }

rm -rf "$PACK"
mkdir -p "$IMG"
cp "$REL/pack_input/package-file" "$PACK/"
cp "$REL/pack_input/Image/parameter.txt" "$IMG/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$IMG/"
cp "$REL/_uboot-memlayout.img" "$IMG/uboot.img"
cp "$REL/_boot-v16.img" "$IMG/boot.img"
cp "$ROOTFS" "$IMG/rootfs.img"
echo "Staged $PACK (rootfs=$(basename "$ROOTFS"))"

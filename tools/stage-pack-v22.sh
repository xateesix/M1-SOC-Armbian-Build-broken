#!/usr/bin/env bash
# Stage v22 pack: explicit rootfs partition (RKDevTool-safe), boot size from boot.img.
# Do NOT use rootfs:grow in parameter.txt  -  RKDevTool leaves rootfs unwritten/corrupt.
# eMMC grow is handled on first boot by rk3308bs-grow-rootfs.service.
set -euo pipefail
REL="$PROJECT_ROOT/output/releases/1.0.0"
FAC="$PROJECT_ROOT/output/factory_fresh/03_partitions"
PACK="$REL/pack_input_v22"
IMG="$PACK/Image"
ROOTFS="${1:-$REL/rootfs-v22.img}"
TOOLS="$PROJECT_ROOT/output/tools"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

[[ -f "$ROOTFS" ]] || { echo "Missing $ROOTFS"; exit 1; }

rm -rf "$PACK"
mkdir -p "$IMG"
cp "$REL/pack_input/package-file" "$PACK/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$IMG/"
cp "$REL/_uboot-memlayout.img" "$IMG/uboot.img"
cp "$REL/_boot-v16.img" "$IMG/boot.img"
cp "$ROOTFS" "$IMG/rootfs.img"

PARAM="$WORKDIR/param.txt"
cp "$REL/pack_input/Image/parameter.txt" "$PARAM"

python3 "$TOOLS/patch-parameter-boot-size.py" \
  "$PARAM" \
  "$IMG/boot.img" \
  "$IMG/parameter.txt" \
  --rootfs "$IMG/rootfs.img"

echo "Staged $PACK (rootfs=$(basename "$ROOTFS"), explicit rootfs partition for RKDevTool)"
grep -E 'CMDLINE|rootfs' "$IMG/parameter.txt" | head -3

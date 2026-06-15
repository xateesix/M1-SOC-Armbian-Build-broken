#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)"
REL="$SCRIPT/releases/1.0.0"
FAC="$SCRIPT/factory_fresh/03_partitions"
TOOLS="$SCRIPT/tools"
PACK="$REL/pack_input_v58"
rm -rf "$PACK"
mkdir -p "$PACK/Image"
cp "$FAC/package-file" "$PACK/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$PACK/Image/"
cp "$REL/_uboot-memlayout.img" "$PACK/Image/uboot.img"
cp "$REL/_boot-v58.img" "$PACK/Image/boot.img"
cp "$REL/rootfs-v57.img" "$PACK/Image/rootfs.img"
python3 "$TOOLS/patch-parameter-boot-size.py" \
  "$FAC/parameter.txt" "$PACK/Image/boot.img" "$PACK/Image/parameter.txt" \
  --rootfs "$PACK/Image/rootfs.img"
bash "$TOOLS/verify-pack-parameter.sh" "$PACK/Image/parameter.txt"
echo STAGED

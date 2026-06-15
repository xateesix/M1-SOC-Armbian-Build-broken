#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
FAC="$SCRIPT_DIR/factory_fresh/03_partitions"
TOOLS="$SCRIPT_DIR/tools"
PACK="$REL/pack_input_v59"
rm -rf "$PACK"
mkdir -p "$PACK/Image"
cp "$FAC/package-file" "$PACK/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$PACK/Image/"
cp "$REL/_uboot-memlayout.img" "$PACK/Image/uboot.img"
cp "$REL/_boot-v59.img" "$PACK/Image/boot.img"
cp "$REL/rootfs-v59.img" "$PACK/Image/rootfs.img"
python3 "$TOOLS/patch-parameter-boot-size.py" \
  "$FAC/parameter.txt" "$PACK/Image/boot.img" "$PACK/Image/parameter.txt" \
  --rootfs "$PACK/Image/rootfs.img"
bash "$TOOLS/verify-pack-parameter.sh" "$PACK/Image/parameter.txt"
echo "STAGED v59"

#!/usr/bin/env bash
# Stage pack_input and pack rk3308bs-1.0.0-emmc-fixed-v12.img (Windows AFPTool + RKImageMaker).
set -euo pipefail
REL="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0"
FAC="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/factory_fresh/03_partitions"
PACK="$REL/pack_input_v12"
IMG="$PACK/Image"

rm -rf "$PACK"
mkdir -p "$IMG"
cp "$REL/pack_input/package-file" "$PACK/"
cp "$REL/pack_input/Image/parameter.txt" "$IMG/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/uboot.img" "$FAC/misc.img" "$FAC/recovery.img" "$IMG/"
cp "$REL/_uboot-memlayout.img" "$IMG/uboot.img"
cp "$REL/_boot-v12.img" "$IMG/boot.img"
cp "$REL/rootfs-v11.img" "$IMG/rootfs.img"
echo "Staged $PACK"
ls -la "$IMG"

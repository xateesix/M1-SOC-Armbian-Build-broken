#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0"
FAC="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/factory_fresh/03_partitions"
PACK="$REL/pack_input_v39"
IMG="$PACK/Image"
ROOTFS="${1:-$REL/rootfs-v39.img}"

[[ -f "$ROOTFS" ]] || { echo "Missing $ROOTFS"; exit 1; }
[[ -f "$REL/_boot-v39.img" ]] || { echo "Missing $REL/_boot-v39.img"; exit 1; }

rm -rf "$PACK"
mkdir -p "$IMG"
cp "$FAC/package-file" "$PACK/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$IMG/"
cp "$REL/_uboot-memlayout.img" "$IMG/uboot.img"
cp "$REL/_boot-v39.img" "$IMG/boot.img"
cp "$ROOTFS" "$IMG/rootfs.img"
python3 "$SCRIPT_DIR/tools/patch-parameter-boot-size.py" \
	"$FAC/parameter.txt" "$IMG/boot.img" "$IMG/parameter.txt" \
	--rootfs "$IMG/rootfs.img"
echo "Staged $PACK (rootfs=$(basename "$ROOTFS"), explicit rootfs @0x17200 for RKDevTool)"
grep -E 'CMDLINE|rootfs' "$IMG/parameter.txt" | head -3

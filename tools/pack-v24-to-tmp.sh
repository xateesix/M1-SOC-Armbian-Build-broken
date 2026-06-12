#!/usr/bin/env bash
set -euo pipefail
REL=/tmp/rk3308bs-v24-build
RREL=/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0
FAC=/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/factory_fresh/03_partitions
WIN_SCRIPT=/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/windows-pack-update.ps1
PACK="$REL/pack_input_v16"
IMG="$PACK/Image"

[[ -f "$REL/rootfs-v24.img" ]] || { echo "Missing $REL/rootfs-v24.img"; exit 1; }

rm -rf "$PACK"
mkdir -p "$IMG"
cp "$RREL/pack_input/package-file" "$PACK/"
cp "$RREL/pack_input/Image/parameter.txt" "$IMG/"
cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$IMG/"
cp "$RREL/_uboot-memlayout.img" "$IMG/uboot.img"
cp "$RREL/_boot-v16.img" "$IMG/boot.img"
cp "$REL/rootfs-v24.img" "$IMG/rootfs.img"
echo "Staged pack in $PACK"
ls -la "$IMG/rootfs.img"

OUT="$REL/rk3308bs-1.0.0-emmc-fixed-v24.img"
WIN_PACK="$(wslpath -w "$PACK")"
WIN_OUT="$(wslpath -w "$OUT")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" \
  -PackInput "$WIN_PACK" -Output "$(basename "$OUT")"

# AFPTool writes firmware.img next to pack input; RKImageMaker writes to pack dir parent
mv -f "$REL/rk3308bs-1.0.0-emmc-fixed-v24.img" "$OUT" 2>/dev/null || true
if [[ -f "$PACK/../rk3308bs-1.0.0-emmc-fixed-v24.img" ]]; then
  mv -f "$PACK/../rk3308bs-1.0.0-emmc-fixed-v24.img" "$OUT"
fi
if [[ -f "$REL/pack_input_v16/rk3308bs-1.0.0-emmc-fixed-v24.img" ]]; then
  mv -f "$REL/pack_input_v16/rk3308bs-1.0.0-emmc-fixed-v24.img" "$OUT"
fi

ls -la "$OUT"
echo "FLASH IMAGE: $OUT"
echo "Copy to releases after freeing C: drive space"

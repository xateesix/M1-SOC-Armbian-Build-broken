#!/usr/bin/env bash
# v59: panel GPIO kernel fix + simple-panel DTB (U-Boot logo) + v57 rootfs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
BUILD_DIR="$SCRIPT_DIR/.build-v59"
export RK3308BS_IMAGE_TAG="v59-panel-enable-fix"

[[ -f "$REL/_Image-v59" ]] || { echo "Run tools/build-kernel-v59-panelfix.sh first"; exit 1; }
[[ -f "$REL/rootfs-v57.img" ]] || { echo "Missing rootfs-v57.img"; exit 1; }

cp -f "$REL/rootfs-v57.img" "$REL/rootfs-v59.img"
bash "$TOOLS/build-boot-v59.sh" "$REL/_Image-v59"
bash "$TOOLS/stage-pack-v58.sh" 2>/dev/null || true
bash "$TOOLS/stage-pack-v59.sh" 2>/dev/null || bash -c '
SCRIPT_DIR="'"$SCRIPT_DIR"'"; REL="'"$REL"'"; FAC="'"$SCRIPT_DIR"'/factory_fresh/03_partitions"; PACK="'"$REL"'/pack_input_v59"; rm -rf "$PACK"; mkdir -p "$PACK/Image"; cp "$FAC/package-file" "$PACK/"; cp "$FAC/MiniLoaderAll.bin" "$FAC/trust.img" "$FAC/misc.img" "$FAC/recovery.img" "$PACK/Image/"; cp "$REL/_uboot-memlayout.img" "$PACK/Image/uboot.img"; cp "$REL/_boot-v59.img" "$PACK/Image/boot.img"; cp "$REL/rootfs-v59.img" "$PACK/Image/rootfs.img"; python3 "'"$TOOLS"'/patch-parameter-boot-size.py" "$FAC/parameter.txt" "$PACK/Image/boot.img" "$PACK/Image/parameter.txt" --rootfs "$PACK/Image/rootfs.img"; bash "'"$TOOLS"'/verify-pack-parameter.sh" "$PACK/Image/parameter.txt"
'
WIN_PACK="$(wslpath -w "$REL/pack_input_v59")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")" \
  -PackInput "$WIN_PACK" -Output "rk3308bs-1.0.0-emmc-fixed-v59.img"
ls -la "$REL/rk3308bs-1.0.0-emmc-fixed-v59.img"
echo "DONE: $REL/rk3308bs-1.0.0-emmc-fixed-v59.img"

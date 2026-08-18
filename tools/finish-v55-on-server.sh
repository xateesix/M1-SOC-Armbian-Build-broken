#!/bin/bash
set -euo pipefail
REL="${REL:-/tmp/armbian-m1-build/releases/1.0.0}"
TOOLS="${TOOLS:-/tmp/armbian-m1-build/tools}"
BD="${BD:-/tmp/armbian-m1-build/.build-v55}"
PACK_SUBDIR="${PACK_SUBDIR:-pack_input}"
STAGE_SCRIPT="${STAGE_SCRIPT:-$TOOLS/stage-pack-v54.sh}"
BOOT_SCRIPT="${BOOT_SCRIPT:-$TOOLS/build-boot-v53.sh}"
VERIFY_SCRIPT="${VERIFY_SCRIPT:-$TOOLS/verify-pack-parameter.sh}"
if [[ -f "$BD/rootfs-expanded.img" && ! -f "$BD/rootfs-v55.img" ]]; then
  bash "$TOOLS/install-kernel-modules-chroot-display.sh" "$BD/rootfs-expanded.img" "$BD/rootfs-v55.img"
fi
cp -f "$BD/rootfs-v55.img" "$REL/rootfs-v55.img"
bash "$BOOT_SCRIPT" "$REL/_Image-v22"
bash "$STAGE_SCRIPT" "$REL/rootfs-v55.img"
bash "$VERIFY_SCRIPT" "$REL/$PACK_SUBDIR/Image/parameter.txt"
ls -lh "$REL/rootfs-v55.img" "$REL/$PACK_SUBDIR/Image/rootfs.img" "$REL/_boot-v53.img"
echo SERVER_STAGE_DONE

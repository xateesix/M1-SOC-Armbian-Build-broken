#!/bin/bash
set -euo pipefail
REL=/tmp/armbian-m1-build/releases/1.0.0
TOOLS=/tmp/armbian-m1-build/tools
BD=/tmp/armbian-m1-build/.build-v55
if [[ -f "$BD/rootfs-expanded.img" && ! -f "$BD/rootfs-v55.img" ]]; then
  bash "$TOOLS/install-kernel-modules-chroot-display.sh" "$BD/rootfs-expanded.img" "$BD/rootfs-v55.img"
fi
cp -f "$BD/rootfs-v55.img" "$REL/rootfs-v55.img"
bash "$TOOLS/build-boot-v53.sh" "$REL/_Image-v22"
bash "$TOOLS/stage-pack-v54.sh" "$REL/rootfs-v55.img"
bash "$TOOLS/verify-pack-parameter.sh" "$REL/pack_input_v54/Image/parameter.txt"
ls -lh "$REL/rootfs-v55.img" "$REL/pack_input_v54/Image/rootfs.img" "$REL/_boot-v53.img"
bash "$TOOLS/notify-discord.sh" "M1-SOC v55: SERVER_STAGE_DONE on $(hostname)"
echo SERVER_STAGE_DONE

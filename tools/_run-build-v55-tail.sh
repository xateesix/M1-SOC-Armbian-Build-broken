#!/usr/bin/env bash
set -euo pipefail
export SSHPASS='ztfalxtspv'
RSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new"
rsync -avz -e "$RSH" /mnt/c/Workspaces/Armbian-M1-SOC/tools/install-kernel-modules-chroot-display.sh xateesix@10.22.2.208:/tmp/armbian-m1-build/tools/
$RSH xateesix@10.22.2.208 'bash -s' <<'REMOTE'
set -euo pipefail
cd /tmp/armbian-m1-build
REL=/tmp/armbian-m1-build/releases/1.0.0
TOOLS=/tmp/armbian-m1-build/tools
BUILD=/tmp/armbian-m1-build/.build-v55
export RK3308BS_IMAGE_TAG=v55-expanded-display
printf '%s\n' 'ztfalxtspv' | sudo -S bash -c "
set -euo pipefail
bash $TOOLS/install-kernel-modules-chroot-display.sh $BUILD/rootfs-expanded.img $BUILD/rootfs-v55.img
cp -f $BUILD/rootfs-v55.img $REL/rootfs-v55.img
bash $TOOLS/build-boot-v53.sh $REL/_Image-v22
bash $TOOLS/stage-pack-v54.sh $REL/rootfs-v55.img
bash $TOOLS/verify-pack-parameter.sh $REL/pack_input_v54/Image/parameter.txt
ls -la $REL/rootfs-v55.img $REL/pack_input_v54/Image/rootfs.img $REL/_boot-v53.img
" 2>&1 | tee -a build-v55.log
REMOTE
#!/usr/bin/env bash
set -euo pipefail
export SSHPASS='ztfalxtspv'
SSH='sshpass -e ssh -o StrictHostKeyChecking=accept-new'
RSYNC='rsync -avz --info=progress2'
RSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new"
SRC=/mnt/c/Workspaces/Armbian-M1-SOC
DST=xateesix@10.22.2.208:/tmp/armbian-m1-build

$SSH xateesix@10.22.2.208 'mkdir -p /tmp/armbian-m1-build'

$RSYNC -e "$RSH" "$SRC/tools/" "$DST/tools/"
$RSYNC -e "$RSH" "$SRC/config.env" "$DST/"
$RSYNC -e "$RSH" "$SRC/userpatches-boot/" "$DST/userpatches-boot/"
$RSYNC -e "$RSH" "$SRC/userpatches-chroot/" "$DST/userpatches-chroot/"
$RSYNC -e "$RSH" "$SRC/factory_fresh/03_partitions/" "$DST/factory_fresh/03_partitions/"

LOCAL_IMG=29866496
REMOTE_SIZE=$($SSH xateesix@10.22.2.208 'stat -c %s /tmp/armbian-m1-build/releases/1.0.0/_Image-v22 2>/dev/null || echo 0')
if [ "$REMOTE_SIZE" = "$LOCAL_IMG" ]; then
  echo "Skip _Image-v22 (same size $LOCAL_IMG)"
else
  $RSYNC -e "$RSH" "$SRC/releases/1.0.0/_Image-v22" "$DST/releases/1.0.0/"
fi

$RSYNC -e "$RSH" "$SRC/releases/1.0.0/rootfs-v11.img" "$DST/releases/1.0.0/"
$RSYNC -e "$RSH" "$SRC/releases/1.0.0/_modules_6.18.0-dirty/" "$DST/releases/1.0.0/_modules_6.18.0-dirty/"
$RSYNC -e "$RSH" "$SRC/releases/1.0.0/_uboot-memlayout.img" "$DST/releases/1.0.0/"

echo "Rsync complete"
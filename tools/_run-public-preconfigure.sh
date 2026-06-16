#!/bin/bash
set -euo pipefail
cd /mnt/c/Workspaces/Armbian-M1-Pro-X1_SOC/Armbian-M1-SOC
source config.env
echo "$SUDO_PASSWORD" | sudo -S env CONFIG=config.env.public.example bash tools/patch-rootfs-preconfigure.sh \
  releases/1.0.0/rootfs-v61.img releases/1.0.0/rootfs-v61-public.img

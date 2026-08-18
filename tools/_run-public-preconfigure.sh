#!/bin/bash
set -euo pipefail
cd $PROJECT_ROOT
source config.env
echo "$SUDO_PASSWORD" | sudo -S env CONFIG=config.env.public.example bash tools/patch-rootfs-preconfigure.sh \
  releases/1.0.0/rootfs-v61.img releases/1.0.0/rootfs-v61-public.img

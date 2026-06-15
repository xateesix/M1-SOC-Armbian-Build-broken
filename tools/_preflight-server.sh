#!/usr/bin/env bash
set -euo pipefail
export SSHPASS='ztfalxtspv'
sshpass -e ssh -o StrictHostKeyChecking=accept-new xateesix@10.22.2.208 'bash -s' <<'REMOTE'
set -euo pipefail
printf '%s\n' 'ztfalxtspv' | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y \
  qemu-user-static qemu-user-binfmt device-tree-compiler lz4 e2fsprogs python3
for c in fdtput lz4 python3 e2fsck resize2fs; do
  command -v "$c"
done
echo Pre-flight OK
REMOTE
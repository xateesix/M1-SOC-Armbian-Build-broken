#!/usr/bin/env bash
set -euo pipefail
export SSHPASS='ztfalxtspv'
RSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new"
rsync -avz -e "$RSH" /mnt/c/Workspaces/Armbian-M1-SOC/tools/ xateesix@10.22.2.208:/tmp/armbian-m1-build/tools/
$RSH xateesix@10.22.2.208 'bash -s' <<'REMOTE'
set -euo pipefail
cd /tmp/armbian-m1-build
printf '%s\n' 'ztfalxtspv' | sudo -S bash -c 'losetup -D 2>/dev/null || true'
: > build-v55.log
printf '%s\n' 'ztfalxtspv' | sudo -S bash tools/build-release-v55-server.sh 2>&1 | tee -a build-v55.log
REMOTE
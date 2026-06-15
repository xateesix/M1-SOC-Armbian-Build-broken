#!/usr/bin/env bash
export SSHPASS='ztfalxtspv'
sshpass -e ssh -o StrictHostKeyChecking=accept-new xateesix@10.22.2.208 'bash -s' <<'REMOTE'
for c in fdtput lz4 python3 e2fsck resize2fs; do
  command -v "$c" || { echo MISSING $c; exit 1; }
done
test -x /usr/bin/qemu-aarch64-static && echo qemu-aarch64-static OK
echo Pre-flight OK
REMOTE
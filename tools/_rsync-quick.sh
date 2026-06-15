#!/usr/bin/env bash
export SSHPASS='ztfalxtspv'
RSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new"
SRC=/mnt/c/Workspaces/Armbian-M1-SOC
rsync -avz -e "$RSH" "$SRC/tools/build-release-v55-server.sh" xateesix@10.22.2.208:/tmp/armbian-m1-build/tools/
rsync -avz -e "$RSH" "$SRC/config.env" xateesix@10.22.2.208:/tmp/armbian-m1-build/
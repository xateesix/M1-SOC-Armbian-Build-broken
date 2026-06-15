#!/usr/bin/env bash
export SSHPASS='ztfalxtspv'
sshpass -e ssh -o StrictHostKeyChecking=accept-new xateesix@10.22.2.208 'tail -30 /tmp/armbian-m1-build/build-v55.log; echo ---; ls -lh /tmp/armbian-m1-build/releases/1.0.0/rootfs-v55.img /tmp/armbian-m1-build/releases/1.0.0/pack_input_v54/Image/rootfs.img /tmp/armbian-m1-build/releases/1.0.0/_boot-v53.img'
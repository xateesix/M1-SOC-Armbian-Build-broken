#!/bin/bash
IMG="/mnt/c/Workspaces/Armbian-M1-Pro-X1_SOC/Armbian-M1-SOC/releases/1.0.0/rootfs-v61.img"
debugfs -R "dump /etc/passwd /tmp/rkpasswd" "$IMG"
grep -E '^(root|m1prox|xatee)' /tmp/rkpasswd

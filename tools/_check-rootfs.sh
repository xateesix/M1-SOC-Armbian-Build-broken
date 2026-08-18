#!/bin/bash
IMG="$PROJECT_ROOT/releases/1.0.0/rootfs-v61.img"
debugfs -R "dump /etc/passwd /tmp/rkpasswd" "$IMG"
grep -E '^(root|m1prox|xatee)' /tmp/rkpasswd

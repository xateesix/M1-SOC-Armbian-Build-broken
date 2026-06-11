#!/usr/bin/env bash
ROOTFS="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0/rootfs-v11.img"
MOD="/lib/modules/6.18.35-current-rockchip64"
echo "=== rockchip drm ==="
debugfs -R "ls ${MOD}/kernel/drivers/gpu/drm/rockchip" "$ROOTFS" 2>/dev/null || echo "(missing dir)"
echo "=== panel ==="
debugfs -R "ls ${MOD}/kernel/drivers/gpu/drm/panel" "$ROOTFS" 2>/dev/null | head -8
echo "=== modules-load.d ==="
debugfs -R "ls /etc/modules-load.d" "$ROOTFS" 2>/dev/null
echo "=== modprobe.d ==="
debugfs -R "ls /etc/modprobe.d" "$ROOTFS" 2>/dev/null | head -10

#!/bin/bash
# Rockchip eMMC GPT uses rootfs:grow  -  use stock armbian-resize-filesystem, not growroot initramfs.
set -euo pipefail

echo "[rk3308bs] Enabling Armbian rootfs resize (Rockchip GPT rootfs:grow) ..."

rm -f /root/.no_rootfs_resize

systemctl unmask armbian-resize-filesystem.service 2>/dev/null || true
systemctl enable armbian-resize-filesystem.service 2>/dev/null || true

# growroot initramfs can fight Rockchip parameter.txt layout on some images
if [[ -f /usr/share/initramfs-tools/hooks/growroot ]]; then
	mv /usr/share/initramfs-tools/hooks/growroot \
		/usr/share/initramfs-tools/hooks/growroot.disabled 2>/dev/null || true
fi
if [[ -f /usr/share/initramfs-tools/scripts/local-bottom/growroot ]]; then
	mv /usr/share/initramfs-tools/scripts/local-bottom/growroot \
		/usr/share/initramfs-tools/scripts/local-bottom/growroot.disabled 2>/dev/null || true
fi

if [[ -f /etc/cron.daily/armbian-quotes ]]; then
	chmod -x /etc/cron.daily/armbian-quotes 2>/dev/null || true
fi

echo "[rk3308bs] armbian-resize-filesystem enabled; growroot initramfs disabled"

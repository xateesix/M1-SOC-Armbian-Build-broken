from pathlib import Path
p = Path(r"/mnt/c/Workspaces/Armbian-M1-SOC/tools/install-kernel-modules-chroot-display.sh")
text = p.read_text()
boot_block = '''
BOOT_STATUS="$MNT/usr/local/sbin/rk3308bs-boot-status.sh"
sudo_cmd tee "$BOOT_STATUS" >/dev/null <<'"'"'EOF'"'"'
#!/bin/bash
TAG=$(head -1 /etc/rk3308bs-release 2>/dev/null || echo unknown)
HOST=$(hostname)
IP=$(hostname -I 2>/dev/null | awk '"'"'{print $1}'"'"')
read -r FB_BLANK < /sys/class/graphics/fb0/blank 2>/dev/null || FB_BLANK=na
read -r BL_PWR < /sys/class/backlight/backlight/bl_power 2>/dev/null || BL_PWR=na
BANNER=$(cat <<BANNER_EOF
 _____________________________
|  RK3308BS Armbian ${TAG}
|  Host: ${HOST}
|  IP:   ${IP:-dhcp-pending}
|  LCD:  fb-blank=${FB_BLANK} bl_power=${BL_PWR}
|  Serial: ttyS3 + ttyFIQ0
|  WiFi: /boot/system.cfg
|_____________________________|
BANNER_EOF
)
for tty in /dev/tty0 /dev/ttyS3; do
  [ -c "$tty" ] && printf '"'"'%s\\n\\n'"'"' "$BANNER" >"$tty" 2>/dev/null || true
done
EOF
sudo_cmd chmod 755 "$BOOT_STATUS"

sudo_cmd tee "$MNT/etc/systemd/system/rk3308bs-boot-status.service" >/dev/null <<'"'"'EOF'"'"'
[Unit]
Description=RK3308BS boot status banner (serial + framebuffer)
After=rk3308bs-display-modules.service
Wants=rk3308bs-display-modules.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-boot-status.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo_cmd ln -sf /etc/systemd/system/rk3308bs-boot-status.service \
	"$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-boot-status.service"
'''
marker = 'sudo_cmd ln -sf /etc/systemd/system/rk3308bs-display-modules.service'
if marker not in text:
    raise SystemExit('marker2 missing')
text = text.replace(marker, boot_block + '\n' + marker, 1)
p.write_text(text)
print('boot status service added')

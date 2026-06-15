#!/bin/bash
# Runs inside Armbian chroot during compile.sh (userpatches/customize-image.sh hook).
# Userland packages and services for Artillery M1 Pro S1-SOC (RK3308BS) hardware.
set -euo pipefail

echo "[rk3308bs] Installing board hardware userland packages ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    network-manager \
    wpasupplicant \
    rfkill \
    i2c-tools \
    evtest \
    libinput-tools \
    kmod \
    ca-certificates

systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable wpa_supplicant.service 2>/dev/null || true

# Console: Armbian 6.18 has no fiq-debugger  -  use raw UART3 (ttyS3 @ 1500000).
# Factory DTB keeps OTP/thermal; fiq-debugger disabled at pack time (--armbian-serial).
mkdir -p /etc/systemd/system/serial-getty@ttyS3.service.d
cat >/etc/systemd/system/serial-getty@ttyS3.service.d/baud1500000.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --keep-baud 115200,1500000,9600 %I $TERM
EOF
systemctl enable serial-getty@ttyS3.service 2>/dev/null || true
systemctl disable serial-getty@ttyFIQ0.service 2>/dev/null || true

mkdir -p /etc/rk3308bs
cat >/etc/rk3308bs/hardware.txt <<'EOF'
Board: Artillery M1 Pro S1-SOC (RK3308BS EVB AMIC V11)
Display: 480x272 RGB + Goodix GT911 (i2c-3/0x5d)
LCD policy: boot messages on fb0 during startup, then Klipper UI (no getty/login on panel)
WiFi: RTL8189CS SDIO (Armbian kernel driver / rtw88)
LEDs: GPIO green PA6, blue PA5
Serial: ttyS3 @ 1500000 (Armbian  -  factory DTB with fiq-debugger disabled)
EOF

systemctl disable getty@tty1.service 2>/dev/null || true

echo "[rk3308bs] Hardware userland configured"

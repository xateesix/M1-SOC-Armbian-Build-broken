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

# Console on UART3 via fiq-debugger while factory boot.img kernel is in use.
systemctl enable serial-getty@ttyFIQ0.service 2>/dev/null || true

# Future: when boot.img ships Armbian kernel + ttyS3 DTB, enable this instead:
# systemctl disable serial-getty@ttyFIQ0.service 2>/dev/null || true
# systemctl enable serial-getty@ttyS3.service 2>/dev/null || true

mkdir -p /etc/rk3308bs
cat >/etc/rk3308bs/hardware.txt <<'EOF'
Board: Artillery M1 Pro S1-SOC (RK3308BS EVB AMIC V11)
Display: 480x272 RGB + Goodix GT911 (i2c-3/0x5d)
WiFi: RTL8189CS SDIO (8189fs kernel module)
LEDs: GPIO green PA6, blue PA5
Console: ttyFIQ0 @ 1500000 (factory boot.img phase)
EOF

echo "[rk3308bs] Hardware userland configured"

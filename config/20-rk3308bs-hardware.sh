#!/bin/bash
# Runs inside Armbian chroot during compile.sh (userpatches/customize-image.sh hook).
# Userland packages and services for Artillery M1 Pro S1-SOC (RK3308BS) hardware.
set -euo pipefail

echo "[rk3308bs] Installing board hardware userland packages ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    netplan.io \
    wpasupplicant \
    iw \
    wireless-tools \
    rfkill \
    firmware-realtek \
    i2c-tools \
    evtest \
    libinput-tools \
    kmod \
    python3 \
    ca-certificates

mkdir -p /lib/firmware
python3 - <<'PY'
from pathlib import Path

fw = Path("/lib/firmware/goodix_911_cfg.bin")
data = bytes.fromhex(
    "00 38 04 80 07 0a 3d 00 01 ca 28 0a 5a 3c 0a 04 00 00 00 00 11 11 00 17 19 1e 14 95 35 ff 2e 30 09 19 "
    "00 00 00 01 04 1c 00 00 00 00 00 00 00 00 00 00 00 19 41 94 45 02 07 00 00 04 9a 1b 00 85 21 ff 74 28 "
    "00 66 31 00 5b 3b 00 5b 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "
    "00 00 00 00 00 1d 1c 1b 1a 19 18 17 16 15 14 13 12 11 10 0f 0e 0d 0c 0b 0a 09 08 07 06 05 04 03 02 01 "
    "00 2a 29 28 27 26 25 24 23 22 21 20 1f 1e 1d 1c 1b 19 18 17 16 15 14 13 12 11 10 0f 0e 0d 0c 0b 0a 09 "
    "08 07 06 05 04 03 02 01 00 89 01"
)
if not fw.exists() or fw.read_bytes() != data:
    fw.write_bytes(data)
PY

systemctl enable systemd-networkd.service 2>/dev/null || true
systemctl enable systemd-resolved.service 2>/dev/null || true

mkdir -p /usr/local/sbin /etc/systemd/system
cat >/usr/local/sbin/rk3308bs-load-wifi.sh <<'EOF'
#!/bin/bash
set -euo pipefail

modprobe rfkill
modprobe libarc4
modprobe cfg80211
modprobe mac80211
modprobe 8189fs
EOF
chmod 0755 /usr/local/sbin/rk3308bs-load-wifi.sh

cat >/etc/systemd/system/rk3308bs-wifi-modules.service <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules before networking
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target systemd-networkd.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 /etc/systemd/system/rk3308bs-wifi-modules.service
systemctl enable rk3308bs-wifi-modules.service 2>/dev/null || true

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
WiFi: RTL8189CS SDIO (rtl8189fs / 8189fs.ko)
LEDs: GPIO green PA6, blue PA5
Serial: ttyS3 @ 1500000 (Armbian  -  factory DTB with fiq-debugger disabled)
EOF

systemctl disable getty@tty1.service 2>/dev/null || true

mkdir -p /usr/local/bin /etc/systemd/system
cat >/usr/local/bin/restore-thermal-trip.sh <<'EOF'
#!/bin/bash
set -euo pipefail

sleep 45

for zone in /sys/class/thermal/thermal_zone*; do
    [ -d "$zone" ] || continue
    for trip in "$zone"/trip_point_*_temp; do
        [ -f "$trip" ] || continue
        current="$(cat "$trip" 2>/dev/null || true)"
        if [[ "$current" =~ ^[0-9]+$ ]] && [ "$current" -ge 120000 ]; then
            echo 115000 > "$trip"
            echo "restored $zone $(basename "$trip") -> 115000"
        fi
    done
done
EOF
chmod 0755 /usr/local/bin/restore-thermal-trip.sh

cat >/etc/systemd/system/restore-thermal-trip.service <<'EOF'
[Unit]
Description=Restore thermal trip points after boot
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/restore-thermal-trip.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload 2>/dev/null || true
systemctl enable restore-thermal-trip.service 2>/dev/null || true

echo "[rk3308bs] Hardware userland configured"

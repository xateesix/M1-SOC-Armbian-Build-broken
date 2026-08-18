#!/usr/bin/env bash
# v62 rootfs: v61 base + LED lightbar/neopixel test tools + leds-pwm module.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
SRC="${1:-$REL/rootfs-v61.img}"
OUT="${2:-$REL/rootfs-v62.img}"
MODULES="$REL/_modules_6.18.0-dirty/lib/modules/6.18.0-dirty"

[[ -f "$SRC" ]] || { echo "Missing $SRC"; exit 1; }
[[ -f "$MODULES/kernel/drivers/leds/leds-pwm.ko" ]] || { echo "Missing leds-pwm.ko"; exit 1; }

cp -f "$SRC" "$OUT"
MNT=$(mktemp -d)
cleanup() { sudo umount "$MNT" 2>/dev/null || true; rm -rf "$MNT"; }
trap cleanup EXIT
sudo mount -o loop "$OUT" "$MNT"

install -m755 "$TOOLS/lightbar-test.sh" "$MNT/usr/local/sbin/lightbar-test.sh"
install -m755 "$TOOLS/neopixel-test.py" "$MNT/usr/local/sbin/neopixel-test.py"
install -m755 "$TOOLS/fb-color-test.py" "$MNT/usr/local/sbin/fb-color-test.py"

MODDIR="$MNT/lib/modules/6.18.0-dirty/kernel/drivers/leds"
sudo mkdir -p "$MODDIR"
sudo cp "$MODULES/kernel/drivers/leds/leds-pwm.ko" "$MODDIR/"
sudo depmod -b "$MNT" 6.18.0-dirty

tee "$MNT/etc/modules-load.d/rk3308bs-lights.conf" >/dev/null <<'EOF'
leds-pwm
EOF

tee "$MNT/etc/systemd/system/rk3308bs-lights-modules.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS load leds-pwm for light bar
DefaultDependencies=no
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe leds-pwm
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf ../rk3308bs-lights-modules.service \
  "$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-lights-modules.service"

sudo umount "$MNT"
echo "Wrote $OUT (lightbar + neopixel test tools, leds-pwm module)"

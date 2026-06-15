#!/usr/bin/env bash
# v64 rootfs: v61 base + lights/neopixel/sd test tools + Armbian MOTD + leds-pwm.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
SRC="${1:-$REL/rootfs-v61.img}"
OUT="${2:-$REL/rootfs-v64.img}"
MODULES="$REL/_modules_6.18.0-dirty/lib/modules/6.18.0-dirty"

[[ -f "$SRC" ]] || { echo "Missing $SRC"; exit 1; }
[[ -f "$MODULES/kernel/drivers/leds/leds-pwm.ko" ]] || { echo "Missing leds-pwm.ko"; exit 1; }

cp -f "$SRC" "$OUT"
MNT=$(mktemp -d)
cleanup() { sudo umount "$MNT" 2>/dev/null || true; rm -rf "$MNT"; }
trap cleanup EXIT
sudo mount -o loop "$OUT" "$MNT"

# --- test tools (strip UTF-8 BOM if present) ---
for f in lightbar-test.sh neopixel-test.py fb-color-test.py probe-sdcard.sh; do
  src="$TOOLS/$f"
  [[ -f "$src" ]] || continue
  sed '1s/^\xEF\xBB\xBF//' "$src" > "$MNT/tmp/$f"
  install -m755 "$MNT/tmp/$f" "$MNT/usr/local/sbin/$f"
done

# --- leds-pwm module ---
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

# --- Armbian ASCII MOTD banner ---
echo rk3308bs-evb | sudo tee "$MNT/etc/hostname" >/dev/null
if ! grep -q rk3308bs-evb "$MNT/etc/hosts" 2>/dev/null; then
  echo "127.0.1.1 rk3308bs-evb" | sudo tee -a "$MNT/etc/hosts" >/dev/null
fi
if [[ -d "$MNT/etc/update-motd.d" ]]; then
  sudo chmod +x "$MNT/etc/update-motd.d/"* 2>/dev/null || true
  sudo rm -f "$MNT/etc/motd" 2>/dev/null || true
fi
for pam in login sshd; do
  [[ -f "$MNT/etc/pam.d/$pam" ]] || continue
  if ! grep -q pam_motd.so "$MNT/etc/pam.d/$pam"; then
    echo "session    optional     pam_motd.so" | sudo tee -a "$MNT/etc/pam.d/$pam" >/dev/null
  fi
done
# broken armbian-quotes cron (exit 6)  -  disable until network quotes work
sudo rm -f "$MNT/etc/cron.daily/armbian-quotes" 2>/dev/null || true

# --- quick test hints on login ---
tee "$MNT/etc/profile.d/rk3308bs-tests.sh" >/dev/null <<'EOF'
# RK3308BS v64 hardware test helpers
if [[ -n "$PS1" && "$(id -u)" -eq 0 ]]; then
  echo "RK3308BS tests: lightbar-test.sh | neopixel-test.py | probe-sdcard.sh | fb-color-test.py"
fi
EOF
chmod 644 "$MNT/etc/profile.d/rk3308bs-tests.sh"

sudo umount "$MNT"
echo "Wrote $OUT (lights + sd + Armbian MOTD)"

#!/usr/bin/env bash
# v64 rootfs patch via debugfs (no sudo mount).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
SRC="${1:-$REL/rootfs-v61.img}"
OUT="${2:-$REL/rootfs-v64.img}"
MODULES="$REL/_modules_6.18.0-dirty/lib/modules/6.18.0-dirty"
STAGE="$REL/_rootfs-v64-stage"
IMG="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

[[ -f "$SRC" ]] || { echo "Missing $SRC"; exit 1; }
cp -f "$SRC" "$OUT"
rm -rf "$STAGE"
mkdir -p "$STAGE/usr/local/sbin" "$STAGE/etc/modules-load.d" \
  "$STAGE/etc/systemd/system/multi-user.target.wants" \
  "$STAGE/etc/profile.d" \
  "$STAGE/etc/systemd/system.conf.d" \
  "$STAGE/lib/modules/6.18.0-dirty/kernel/drivers/leds"

for f in lightbar-test.sh neopixel-test.py fb-color-test.py probe-sdcard.sh; do
  [[ -f "$TOOLS/$f" ]] || continue
  sed '1s/^\xEF\xBB\xBF//' "$TOOLS/$f" > "$STAGE/usr/local/sbin/$f"
  chmod 755 "$STAGE/usr/local/sbin/$f"
done

cp "$MODULES/kernel/drivers/leds/leds-pwm.ko" \
  "$STAGE/lib/modules/6.18.0-dirty/kernel/drivers/leds/"

cat > "$STAGE/etc/modules-load.d/rk3308bs-lights.conf" <<EOF
leds-pwm
EOF

cat > "$STAGE/etc/systemd/system/rk3308bs-lights-modules.service" <<EOF
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
ln -sf ../rk3308bs-lights-modules.service \
  "$STAGE/etc/systemd/system/multi-user.target.wants/rk3308bs-lights-modules.service"

echo rk3308bs-evb > "$STAGE/etc/hostname"
cat > "$STAGE/etc/profile.d/rk3308bs-tests.sh" <<'EOF'
if [[ -n "$PS1" && "$(id -u)" -eq 0 ]]; then
  echo "RK3308BS tests: lightbar-test.sh | neopixel-test.py | probe-sdcard.sh | fb-color-test.py"
fi
EOF
chmod 644 "$STAGE/etc/profile.d/rk3308bs-tests.sh"

cat > "$STAGE/etc/systemd/system.conf.d/fbcon-no-color.conf" <<EOF
[Manager]
# Framebuffer boot console tty0 cannot render systemd ANSI status colors.
DefaultEnvironment=SYSTEMD_COLORS=0
EOF
chmod 644 "$STAGE/etc/systemd/system.conf.d/fbcon-no-color.conf"

df_write() {
  local src="$1" dst="$2"
  debugfs -w -R "rm $dst" "$IMG" 2>/dev/null || true
  debugfs -w -R "write $src $dst" "$IMG" | tail -1
}

df_write "$STAGE/etc/hostname" /etc/hostname
df_write "$STAGE/etc/modules-load.d/rk3308bs-lights.conf" /etc/modules-load.d/rk3308bs-lights.conf
df_write "$STAGE/etc/systemd/system/rk3308bs-lights-modules.service" /etc/systemd/system/rk3308bs-lights-modules.service
df_write "$STAGE/etc/profile.d/rk3308bs-tests.sh" /etc/profile.d/rk3308bs-tests.sh
debugfs -w -R "mkdir /etc/systemd/system.conf.d" "$IMG" 2>/dev/null || true
df_write "$STAGE/etc/systemd/system.conf.d/fbcon-no-color.conf" /etc/systemd/system.conf.d/fbcon-no-color.conf
df_write "$STAGE/lib/modules/6.18.0-dirty/kernel/drivers/leds/leds-pwm.ko" \
  /lib/modules/6.18.0-dirty/kernel/drivers/leds/leds-pwm.ko

for f in lightbar-test.sh neopixel-test.py fb-color-test.py probe-sdcard.sh; do
  [[ -f "$STAGE/usr/local/sbin/$f" ]] || continue
  df_write "$STAGE/usr/local/sbin/$f" "/usr/local/sbin/$f"
done

debugfs -w -R "rm /etc/cron.daily/armbian-quotes" "$IMG" 2>/dev/null || true
debugfs -w -R "mkdir /etc/systemd/system/multi-user.target.wants" "$IMG" 2>/dev/null || true
debugfs -w -R "symlink ../rk3308bs-lights-modules.service /etc/systemd/system/multi-user.target.wants/rk3308bs-lights-modules.service" "$IMG" 2>/dev/null || true

# MOTD: ensure all update-motd.d scripts are executable
for n in 00-clear 10-armbian-header 15-ap-info 20-ip-info 25-containers-info 30-armbian-sysinfo 35-armbian-tips 41-commands 98-armbian-autoreboot-warn; do
  debugfs -w -R "set_inode_field /etc/update-motd.d/$n mode 0100755" "$IMG" 2>/dev/null || true
done
debugfs -w -R "rm /etc/motd" "$IMG" 2>/dev/null || true


# Artillery branding in login banner
HDR="$STAGE/10-armbian-header"
debugfs -R "dump /etc/update-motd.d/10-armbian-header $HDR" "$IMG" 2>/dev/null || true
if [[ -f "$HDR" ]]; then
  bash "$TOOLS/patch-motd-artillery.sh" "$HDR"
  df_write "$HDR" /etc/update-motd.d/10-armbian-header
  debugfs -w -R "set_inode_field /etc/update-motd.d/10-armbian-header mode 0100755" "$IMG" 2>/dev/null || true
fi
rm -f "$HDR"
echo "Wrote $OUT via debugfs (lights + sd + MOTD helpers)"



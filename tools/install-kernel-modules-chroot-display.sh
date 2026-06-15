#!/usr/bin/env bash
# Install WiFi + LCD modules via loop mount + depmod (display on multi-user.target).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
CONFIG="$SCRIPT_DIR/config.env"
SRC_ROOTFS="${1:-$REL/rootfs-expanded.img}"
OUT_ROOTFS="${2:-$REL/rootfs-v55.img}"
MOD_SRC="${3:-$REL/_modules_6.18.0-dirty}"
KVER="6.18.0-dirty"
MOD_BASE="/usr/lib/modules/${KVER}"
FULL_DEP="$MOD_SRC/lib/modules/$KVER/modules.dep"

[[ -f "$SRC_ROOTFS" ]] || { echo "Missing $SRC_ROOTFS"; exit 1; }
[[ -f "$FULL_DEP" ]] || { echo "Missing $FULL_DEP"; exit 1; }

DISPLAY_ROOTS=(
	kernel/drivers/gpu/drm/rockchip/rockchipdrm.ko
)
WIFI_ROOTS=(
	kernel/net/rfkill/rfkill.ko
	kernel/lib/crypto/libarc4.ko
	kernel/net/wireless/cfg80211.ko
	kernel/net/mac80211/mac80211.ko
	kernel/drivers/net/wireless/rtl8189fs/8189fs.ko
)

mapfile -t DISPLAY_MODS < <(bash "$TOOLS/_resolve-mod-deps.sh" "$FULL_DEP" "${DISPLAY_ROOTS[@]}")
mapfile -t WIFI_MODS < <(bash "$TOOLS/_resolve-mod-deps.sh" "$FULL_DEP" "${WIFI_ROOTS[@]}")

declare -A MODS=()
add_mod() {
	local rel="$1"
	local src="$MOD_SRC/lib/modules/$KVER/$rel"
	[[ -f "$src" ]] || { echo "Missing module: $src"; exit 1; }
	MODS[$rel]="$src"
}
for rel in "${DISPLAY_MODS[@]}" "${WIFI_MODS[@]}"; do add_mod "$rel"; done

mapfile -t DISPLAY_CORE_ORDER < <(bash "$TOOLS/_topo-mod-order.sh" "$FULL_DEP" "${DISPLAY_MODS[@]}")
DISPLAY_ORDER=("${DISPLAY_CORE_ORDER[@]}")
mapfile -t WIFI_ORDER < <(bash "$TOOLS/_topo-mod-order.sh" "$FULL_DEP" "${WIFI_MODS[@]}")

sudo_cmd() {
	if [[ $EUID -eq 0 ]]; then
		"$@"
		return 0
	fi
	if sudo -n true 2>/dev/null; then
		sudo "$@"
	elif [[ -f "$CONFIG" ]]; then
		# shellcheck source=/dev/null
		source "$CONFIG"
		if [[ -n "${SUDO_PASSWORD:-}" ]]; then
			echo "$SUDO_PASSWORD" | sudo -S "$@"
			return
		fi
	fi
	return 1
}

if ! sudo_cmd true; then
	echo "Need root or passwordless sudo for loop mount"
	exit 1
fi

WORKDIR="$(mktemp -d)"
MNT="$WORKDIR/mnt"
trap 'sudo_cmd umount "$MNT" 2>/dev/null || true; rm -rf "$WORKDIR"' EXIT

cp "$SRC_ROOTFS" "$WORKDIR/rootfs.img"
mkdir -p "$MNT"
sudo_cmd mount -o loop "$WORKDIR/rootfs.img" "$MNT"

for rel in "${!MODS[@]}"; do
	src="${MODS[$rel]}"
	dest="$MNT${MOD_BASE}/$rel"
	sudo_cmd mkdir -p "$(dirname "$dest")"
	sudo_cmd cp -a "$src" "$dest"
done

LOAD_DISPLAY="$MNT/usr/local/sbin/rk3308bs-load-display.sh"
sudo_cmd mkdir -p "$MNT/usr/local/sbin"
{
	echo '#!/bin/bash'
	echo 'set -uo pipefail'
	echo "M=${MOD_BASE}/kernel"
	echo 'export PATH=/sbin:/usr/sbin:/bin:/usr/bin'
	echo 'log() { echo "RK3308BS-LCD: $*" >/dev/kmsg; }'
	echo 'insmod_one() {'
	echo '  local rel="$1"'
	echo '  local path="$M/${rel#kernel/}"'
	echo '  log "insmod ${rel#kernel/}"'
	echo '  if timeout 20 insmod "$path"; then'
	echo '    log "ok ${rel#kernel/}"'
	echo '  else'
	echo '    log "FAIL/skip ${rel#kernel/} exit=$?"'
	echo '  fi'
	echo '}'
	echo 'mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null || true'
	echo 'if [ -f /sys/kernel/debug/devices_deferred/scan ]; then echo 1 >/sys/kernel/debug/devices_deferred/scan; fi'
	echo 'log "panel-builtin=$(ls -1 /sys/bus/platform/drivers/panel-simple/ 2>/dev/null | tr "\\n" " ")"'
	echo 'if [ -d /sys/devices/platform/panel ] && [ ! -e /sys/bus/platform/drivers/panel-simple/panel ]; then'
	echo '  if echo panel > /sys/bus/platform/drivers/panel-simple/bind 2>/dev/null; then'
	echo '    log "panel manual bind ok"'
	echo '  else'
	echo '    log "panel manual bind skipped or failed"'
	echo '  fi'
	echo 'fi'
	for rel in "${DISPLAY_ORDER[@]}"; do
		echo "insmod_one \"${rel}\""
	done
	echo 'sleep 0.5'
	echo 'if [ -f /sys/kernel/debug/devices_deferred/scan ]; then'
	echo '  echo 1 >/sys/kernel/debug/devices_deferred/scan'
	echo '  log "deferred scan"'
	echo 'fi'
	echo 'if [ ! -d /sys/class/drm/card0 ]; then'
	echo '  log "no card0; reload rockchipdrm stack"'
	echo '  for _ in 1 2 3; do'
	echo '    lsmod | grep -q rockchipdrm || break'
	echo '    timeout 5 rmmod rockchipdrm 2>/dev/null || break'
	echo '  done'
	echo '  sleep 0.2'
	echo '  insmod_one "kernel/drivers/gpu/drm/rockchip/rockchipdrm.ko"'
	echo '  if [ -f /sys/kernel/debug/devices_deferred/scan ]; then echo 1 >/sys/kernel/debug/devices_deferred/scan; fi'
	echo 'fi'
	echo 'for bl in /sys/class/backlight/*/brightness; do'
	echo '  [[ -f "$bl" ]] && echo 255 >"$bl"'
	echo 'done'
	echo 'for bp in /sys/class/backlight/*/bl_power; do'
	echo '  [[ -f "$bp" ]] && echo 0 >"$bp"'
	echo 'done'
	echo 'log "drm=$(ls -1 /sys/class/drm/ 2>/dev/null | tr "\n" " ")"'
	echo 'log "backlight=$(ls -1 /sys/class/backlight/ 2>/dev/null | tr "\n" " ")"'
	echo 'log "fb=$(ls -1 /sys/class/graphics/ 2>/dev/null | tr "\n" " ")"'
	echo 'for fb in /sys/class/graphics/fb*/blank; do'
	echo '  [[ -f "$fb" ]] && echo 0 >"$fb"'
	echo 'done'
	echo 'if command -v setterm >/dev/null && [ -c /dev/tty0 ]; then'
	echo '  setterm -blank 0 -powerdown 0 -powersave off </dev/tty0 >/dev/tty0 2>/dev/null || true'
	echo 'fi'
	echo 'log "fb-blank=$(cat /sys/class/graphics/fb0/blank 2>/dev/null || echo na)"'
	echo 'log "panel-drv=$(ls -1 /sys/bus/platform/drivers/panel-simple/ 2>/dev/null | tr "\n" " ")"'
	echo 'log "done"'
} | sudo_cmd tee "$LOAD_DISPLAY" >/dev/null
sudo_cmd chmod 755 "$LOAD_DISPLAY"

LOAD_WIFI="$MNT/usr/local/sbin/rk3308bs-load-wifi.sh"
{
	echo '#!/bin/bash'
	echo 'set -uo pipefail'
	echo "M=${MOD_BASE}/kernel"
	echo 'export PATH=/sbin:/usr/sbin:/bin:/usr/bin'
	echo 'log() { echo "RK3308BS-WIFI: $*" >/dev/kmsg; }'
	echo 'for f in /sys/class/rfkill/rfkill*/soft; do'
	echo '  [[ -f "$f" ]] && echo 0 >"$f" 2>/dev/null || true'
	echo 'done'
	for rel in "${WIFI_ORDER[@]}"; do
		echo "insmod \"\$M/${rel#kernel/}\" 2>/dev/null || log \"skip ${rel#kernel/}\""
	done
	echo 'log "wifi modules loaded: $(lsmod | grep -E \"8189fs|cfg80211\" | tr \"\\n\" \" \")"'
} | sudo_cmd tee "$LOAD_WIFI" >/dev/null
sudo_cmd chmod 755 "$LOAD_WIFI"

sudo_cmd tee "$MNT/etc/systemd/system/rk3308bs-display-modules.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS load LCD DRM modules (480x272 RGB)
DefaultDependencies=no
After=local-fs.target sysinit.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-display.sh
RemainAfterExit=yes
TimeoutStartSec=90

[Install]
WantedBy=multi-user.target
EOF

sudo_cmd tee "$MNT/etc/systemd/system/rk3308bs-wifi-modules.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules
DefaultDependencies=no
After=local-fs.target basic.target
Before=network-pre.target wpa-wlan0.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

sudo_cmd rm -f "$MNT/etc/systemd/system/rk3308bs-display-modules.timer"
sudo_cmd rm -f "$MNT/etc/systemd/system/timers.target.wants/rk3308bs-display-modules.timer"
sudo_cmd mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"

BOOT_STATUS="$MNT/usr/local/sbin/rk3308bs-boot-status.sh"
sudo_cmd tee "$BOOT_STATUS" >/dev/null <<'EOF'
#!/bin/bash
TAG=$(head -1 /etc/rk3308bs-release 2>/dev/null || echo unknown)
HOST=$(hostname)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
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
  [ -c "$tty" ] && printf '%s\n\n' "$BANNER" >"$tty" 2>/dev/null || true
done
EOF
sudo_cmd chmod 755 "$BOOT_STATUS"

sudo_cmd tee "$MNT/etc/systemd/system/rk3308bs-boot-status.service" >/dev/null <<'EOF'
[Unit]
Description=RK3308BS boot status banner (serial + framebuffer)
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-boot-status.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo_cmd ln -sf /etc/systemd/system/rk3308bs-boot-status.service 	"$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-boot-status.service"

sudo_cmd ln -sf /etc/systemd/system/rk3308bs-display-modules.service \
	"$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-display-modules.service"
sudo_cmd ln -sf /etc/systemd/system/rk3308bs-wifi-modules.service \
	"$MNT/etc/systemd/system/multi-user.target.wants/rk3308bs-wifi-modules.service"

sudo_cmd depmod -b "$MNT" "$KVER"
sudo_cmd umount "$MNT"
cp "$WORKDIR/rootfs.img" "$OUT_ROOTFS"
trap - EXIT
rm -rf "$WORKDIR"
echo "Wrote $OUT_ROOTFS (${KVER}: LCD+WiFi via chroot mount, $((${#MODS[@]})) .ko files, display=multi-user.target)"

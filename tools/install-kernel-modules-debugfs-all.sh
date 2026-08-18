#!/usr/bin/env bash
# Install WiFi + LCD (DRM) 6.18.0-dirty modules via debugfs (no sudo loop mount).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
SRC_ROOTFS="${1:-$REL/rootfs-patched.img}"
OUT_ROOTFS="${2:-$REL/rootfs-v25.img}"
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

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cp "$SRC_ROOTFS" "$WORKDIR/rootfs.img"
DST="$WORKDIR/rootfs.img"

LOAD_DISPLAY="$WORKDIR/rk3308bs-load-display.sh"
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
	echo 'log "drm=$(ls -1 /sys/class/drm/ 2>/dev/null | tr "\n" " ")"'
	echo 'log "backlight=$(ls -1 /sys/class/backlight/ 2>/dev/null | tr "\n" " ")"'
	echo 'log "fb=$(ls -1 /sys/class/graphics/ 2>/dev/null | tr "\n" " ")"'
	echo 'log "panel-drv=$(ls -1 /sys/bus/platform/drivers/panel-simple/ 2>/dev/null | tr "\n" " ")"'
	echo 'log "done"'
} >"$LOAD_DISPLAY"

LOAD_WIFI="$WORKDIR/rk3308bs-load-wifi.sh"
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
} >"$LOAD_WIFI"

DISPLAY_UNIT="$WORKDIR/rk3308bs-display-modules.service"
cat >"$DISPLAY_UNIT" <<'EOF'
[Unit]
Description=RK3308BS load LCD DRM modules (480x272 RGB)
DefaultDependencies=no
After=local-fs.target multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-display.sh
RemainAfterExit=yes
TimeoutStartSec=90
EOF

DISPLAY_TIMER="$WORKDIR/rk3308bs-display-modules.timer"
cat >"$DISPLAY_TIMER" <<'EOF'
[Unit]
Description=RK3308BS delayed LCD DRM module load (after boot settles)

[Timer]
OnBootSec=45s
Unit=rk3308bs-display-modules.service

[Install]
WantedBy=timers.target
EOF

WIFI_UNIT="$WORKDIR/rk3308bs-networking.service"
cat >"$WIFI_UNIT" <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules before networking
DefaultDependencies=no
After=local-fs.target basic.target
Before=network-pre.target systemd-networkd.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

MODULES_DEP="$WORKDIR/modules.dep"
: >"$MODULES_DEP"
for rel in "${!MODS[@]}"; do
	grep -F "$rel:" "$FULL_DEP" >>"$MODULES_DEP" 2>/dev/null || echo "$rel:" >>"$MODULES_DEP"
done

declare -A MKDONE=()
mkdir_p() {
	local path="$1"
	local acc=""
	IFS='/' read -r -a parts <<<"${path#/}"
	for part in "${parts[@]}"; do
		acc="${acc}/${part}"
		[[ -n "${MKDONE[$acc]:-}" ]] && continue
		MKDONE[$acc]=1
		echo "mkdir $acc" >>"$CMD"
	done
}

CMD="$WORKDIR/debugfs.cmd"
: >"$CMD"
mkdir_p "/usr/lib/modules/${KVER}"
mkdir_p "/usr/lib/modules/${KVER}/kernel"
for rel in "${!MODS[@]}"; do
	src="${MODS[$rel]}"
	dir="${MOD_BASE}/$(dirname "$rel")"
	mkdir_p "$dir"
	echo "write $src ${MOD_BASE}/$rel" >>"$CMD"
done
cat >>"$CMD" <<EOF
write $MODULES_DEP /usr/lib/modules/${KVER}/modules.dep
write $LOAD_DISPLAY /usr/local/sbin/rk3308bs-load-display.sh
write $LOAD_WIFI /usr/local/sbin/rk3308bs-load-wifi.sh
write $DISPLAY_UNIT /etc/systemd/system/rk3308bs-display-modules.service
write $DISPLAY_TIMER /etc/systemd/system/rk3308bs-display-modules.timer
write $WIFI_UNIT /etc/systemd/system/rk3308bs-wifi-modules.service
mkdir /etc/systemd/system/timers.target.wants
ln /etc/systemd/system/rk3308bs-display-modules.timer /etc/systemd/system/timers.target.wants/rk3308bs-display-modules.timer
mkdir /etc/systemd/system/multi-user.target.wants
ln /etc/systemd/system/rk3308bs-wifi-modules.service /etc/systemd/system/multi-user.target.wants/rk3308bs-wifi-modules.service
quit
EOF

debugfs -w "$DST" -f "$CMD" 2>&1 | grep -v 'already exists' || true
cp "$DST" "$OUT_ROOTFS"
echo "Wrote $OUT_ROOTFS (${KVER}: LCD timer+WiFi modules via debugfs, $((${#MODS[@]})) .ko files)"
echo "Enable LCD timer on first boot: systemctl enable --now rk3308bs-display-modules.timer"

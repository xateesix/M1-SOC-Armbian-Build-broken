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
	kernel/drivers/gpu/drm/panel/panel-simple.ko
	kernel/drivers/video/backlight/pwm_bl.ko
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

mapfile -t DISPLAY_CORE_ORDER < <(bash "$TOOLS/_topo-mod-order.sh" "$FULL_DEP" $(printf '%s\n' "${DISPLAY_MODS[@]}" | grep -vE 'panel-simple|pwm_bl'))
# Backlight before panel (panel DT has backlight= phandle); panel before rockchipdrm (vop_bind needs panel).
DISPLAY_ORDER=("kernel/drivers/video/backlight/pwm_bl.ko" "kernel/drivers/gpu/drm/panel/panel-simple.ko" "${DISPLAY_CORE_ORDER[@]}")
mapfile -t WIFI_ORDER < <(bash "$TOOLS/_topo-mod-order.sh" "$FULL_DEP" "${WIFI_MODS[@]}")

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cp "$SRC_ROOTFS" "$WORKDIR/rootfs.img"
DST="$WORKDIR/rootfs.img"

LOAD_DISPLAY="$WORKDIR/rk3308bs-load-display.sh"
{
	echo '#!/bin/bash'
	echo 'set -euo pipefail'
	echo "M=${MOD_BASE}/kernel"
	echo 'log() { echo "RK3308BS-LCD: $*" >/dev/kmsg; }'
	for rel in "${DISPLAY_ORDER[@]}"; do
		echo "log insmod ${rel#kernel/}"
		echo "insmod \"\$M/${rel#kernel/}\""
	done
	echo 'if [ -f /sys/kernel/debug/devices_deferred/scan ]; then echo 1 >/sys/kernel/debug/devices_deferred/scan; fi'
	echo 'if [ ! -d /sys/class/drm/card0 ] && lsmod | grep -q rockchipdrm; then'
	echo '  log reload rockchipdrm'
	echo '  rmmod rockchipdrm 2>/dev/null || true'
	echo '  insmod "$M/drivers/gpu/drm/rockchip/rockchipdrm.ko"'
	echo 'fi'
	echo 'for bl in /sys/class/backlight/*/brightness; do'
	echo '  [[ -f "$bl" ]] && echo 255 >"$bl"'
	echo 'done'
} >"$LOAD_DISPLAY"

LOAD_WIFI="$WORKDIR/rk3308bs-load-wifi.sh"
{
	echo '#!/bin/bash'
	echo 'set -euo pipefail'
	echo "M=${MOD_BASE}/kernel"
	for rel in "${WIFI_ORDER[@]}"; do
		echo "insmod \"\$M/${rel#kernel/}\""
	done
} >"$LOAD_WIFI"

DISPLAY_UNIT="$WORKDIR/rk3308bs-display-modules.service"
cat >"$DISPLAY_UNIT" <<'EOF'
[Unit]
Description=RK3308BS load LCD DRM modules (480x272 RGB)
DefaultDependencies=no
After=local-fs.target
Before=systemd-udev-settle.service sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-display.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

WIFI_UNIT="$WORKDIR/rk3308bs-wifi-modules.service"
cat >"$WIFI_UNIT" <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules
DefaultDependencies=no
After=local-fs.target rk3308bs-display-modules.service
Before=network-pre.target wpa-wlan0.service
Wants=rk3308bs-display-modules.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes

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
write $WIFI_UNIT /etc/systemd/system/rk3308bs-wifi-modules.service
quit
EOF

debugfs -w "$DST" -f "$CMD" 2>&1 | grep -v 'already exists' || true
cp "$DST" "$OUT_ROOTFS"
echo "Wrote $OUT_ROOTFS (${KVER}: LCD+WiFi modules via debugfs, $((${#MODS[@]})) .ko files)"

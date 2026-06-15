#!/bin/bash
# Run ON the RK3308BS (or via: plink root@IP 'bash -s' < live-display-fix.sh)
# Fixes v36 loader bug, brings up DRM stack, tries panel bind — no reflash needed.
set -eo pipefail

M=/usr/lib/modules/$(uname -r)/kernel
log() { echo "RK3308BS-LCD: $*" | tee /dev/kmsg; }

log "=== live-display-fix start kernel=$(uname -r) ==="

# Fix broken loader script in place (set -u + local rel on same line)
LOADER=/usr/local/sbin/rk3308bs-load-display.sh
if [[ -f "$LOADER" ]]; then
	cp -a "$LOADER" "${LOADER}.bak"
	sed -i 's/set -euo pipefail/set -eo pipefail/' "$LOADER"
	sed -i 's/local rel="\$1" path="\$M\/\${rel#kernel\/}"/local rel="\$1"\n  local path="\$M\/\${rel#kernel\/}"/' "$LOADER"
	sed -i 's/insmod_one kernel\/drivers\/gpu\/drm\/rockchip\/rockchipdrm.ko/insmod_one "kernel\/drivers\/gpu\/drm\/rockchip\/rockchipdrm.ko"/' "$LOADER"
	log "patched $LOADER (backup ${LOADER}.bak)"
fi

mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
[[ -f /sys/kernel/debug/devices_deferred/scan ]] && echo 1 >/sys/kernel/debug/devices_deferred/scan

log "panel driver: $(ls -1 /sys/bus/platform/drivers/panel-simple/ 2>/dev/null | tr '\n' ' ')"
log "platform panel: $(ls -d /sys/devices/platform/panel* 2>/dev/null | tr '\n' ' ')"

if [[ -d /sys/devices/platform/panel ]] && [[ ! -e /sys/bus/platform/drivers/panel-simple/panel ]]; then
	log "trying manual panel bind..."
	if echo panel >/sys/bus/platform/drivers/panel-simple/bind 2>&1 | tee /dev/kmsg; then
		log "panel bind ok"
	else
		log "panel bind failed (see dmesg)"
	fi
fi

insmod_one() {
	local rel="$1"
	local path="$M/${rel#kernel/}"
	log "insmod ${rel#kernel/}"
	insmod "$path" && log "ok ${rel#kernel/}" || log "FAIL ${rel#kernel/}"
}

# Topological order for rockchipdrm deps
for ko in \
	kernel/drivers/media/cec/core/cec.ko \
	kernel/drivers/gpu/drm/display/drm_display_helper.ko \
	kernel/drivers/gpu/drm/bridge/analogix/analogix_dp.ko \
	kernel/drivers/gpu/drm/bridge/synopsys/dw-dp.ko \
	kernel/drivers/gpu/drm/bridge/synopsys/dw-hdmi-qp.ko \
	kernel/drivers/gpu/drm/bridge/synopsys/dw-hdmi.ko \
	kernel/drivers/gpu/drm/bridge/synopsys/dw-mipi-dsi.ko \
	kernel/drivers/gpu/drm/bridge/synopsys/dw-mipi-dsi2.ko \
	kernel/drivers/gpu/drm/display/drm_dp_aux_bus.ko \
	kernel/drivers/gpu/drm/rockchip/rockchipdrm.ko
do
	[[ -f "$M/${ko#kernel/}" ]] || { log "missing $ko"; continue; }
	insmod_one "$ko" || true
done

sleep 0.5
[[ -f /sys/kernel/debug/devices_deferred/scan ]] && echo 1 >/sys/kernel/debug/devices_deferred/scan

if [[ ! -d /sys/class/drm/card0 ]]; then
	log "no card0 after load; retry panel bind + rockchipdrm reload"
	echo panel >/sys/bus/platform/drivers/panel-simple/bind 2>/dev/null || true
	while lsmod | grep -q rockchipdrm; do rmmod rockchipdrm 2>/dev/null || break; done
	insmod_one kernel/drivers/gpu/drm/rockchip/rockchipdrm.ko || true
	[[ -f /sys/kernel/debug/devices_deferred/scan ]] && echo 1 >/sys/kernel/debug/devices_deferred/scan
fi

for bl in /sys/class/backlight/*/brightness; do
	[[ -f "$bl" ]] && echo 255 >"$bl"
done

for bp in /sys/class/backlight/*/bl_power; do
	[[ -f "$bp" ]] && echo 0 >"$bp"
done

log "drm=$(ls -1 /sys/class/drm/ 2>/dev/null | tr '\n' ' ')"
log "fb=$(ls -1 /sys/class/graphics/ 2>/dev/null | tr '\n' ' ')"
log "panel-drv=$(ls -1 /sys/bus/platform/drivers/panel-simple/ 2>/dev/null | tr '\n' ' ')"

echo "=== dmesg panel/drm (last 40) ==="
dmesg | grep -iE 'panel-simple|rockchip-drm|rockchip-rgb|rockchip-vop|fb0|deferred|RK3308BS-LCD' | tail -40

echo "=== sysfs ==="
ls -la /sys/class/drm/ 2>&1
ls -la /sys/class/graphics/ 2>&1
ls -la /sys/bus/platform/drivers/panel-simple/ 2>&1

if [[ -c /dev/fb0 ]]; then
	log "fb0 exists — test pattern"
	dd if=/dev/urandom of=/dev/fb0 bs=4096 count=64 status=none 2>/dev/null && log "wrote noise to fb0" || log "fb0 write failed"
fi

log "=== live-display-fix done ==="

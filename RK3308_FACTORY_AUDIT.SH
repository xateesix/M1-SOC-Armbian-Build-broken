#!/bin/bash
# RK3308 factory-vs-Armbian audit — run ON THE BOARD (SSH or serial shell).
# Collects boot chain, console, GPIO/PWM/display/LEDs, and device-tree facts
# needed to compare against factory_fresh/ extraction and Armbian DTS.
#
# Usage:
#   chmod +x RK3308_FACTORY_AUDIT.SH
#   sudo ./RK3308_FACTORY_AUDIT.SH
#
# Copy the output folder back to your PC (scp, USB stick, or paste REPORT.txt).

set -uo pipefail

OUTPUT_DIR="rk3308_factory_audit"
mkdir -p "$OUTPUT_DIR"

log() { echo "$*" | tee -a "$OUTPUT_DIR/REPORT.txt"; }

dt_read() {
    local relpath="$1"
    local fallback="${2:-}"
    local f="/sys/firmware/devicetree/base/${relpath}"
    if [[ -f "$f" ]]; then
        tr '\0' ' \n' < "$f" | sed 's/[[:space:]]*$//'
    else
        echo "${fallback:-<missing: ${relpath}>}"
    fi
}

dt_find_prop() {
    local prop="$1"
    find /sys/firmware/devicetree/base -type f -name "$prop" 2>/dev/null \
        | while read -r f; do
            local node
            node=$(dirname "$f" | sed 's|.*/base/||')
            printf '%s: ' "$node"
            tr '\0' ' ' < "$f"
            echo
        done
}

dt_nodes_by_compatible() {
    local pattern="$1"
    local out="$2"
    : > "$out"
    find /sys/firmware/devicetree/base -type f -name compatible 2>/dev/null \
        | while read -r f; do
            if tr '\0' '\n' < "$f" | grep -qi "$pattern"; then
                node=$(dirname "$f" | sed 's|.*/base/||')
                compat=$(tr '\0' ' ' < "$f")
                st=$(dt_read "${node}/status" "okay")
                echo "${node} | status=${st} | compatible=${compat}" >> "$out"
            fi
        done
}

dt_node_status_list() {
    local prefix="$1"
    local out="$2"
    : > "$out"
    find /sys/firmware/devicetree/base -mindepth 1 -maxdepth 3 -type d 2>/dev/null \
        | while read -r d; do
            node=$(echo "$d" | sed 's|.*/base/||')
            [[ "$node" == ${prefix}* ]] || continue
            [[ -f "${d}/status" ]] || continue
            st=$(tr '\0' ' ' < "${d}/status")
            echo "${node}: status=${st}" >> "$out"
        done
}

section() {
    echo "" | tee -a "$OUTPUT_DIR/REPORT.txt"
    echo "========== $* ==========" | tee -a "$OUTPUT_DIR/REPORT.txt"
}

: > "$OUTPUT_DIR/REPORT.txt"
log "RK3308 factory audit — $(date -Is 2>/dev/null || date)"
log "hostname: $(hostname 2>/dev/null || echo unknown)"
log "output:   $(pwd)/${OUTPUT_DIR}/"

section "1) IDENTITY (compare to factory_fresh/05_dts/rk3308-factory.dts)"
log "model:      $(dt_read model)"
log "compatible: $(dt_read compatible)"
uname -a | tee "$OUTPUT_DIR/uname.txt" | log "uname:      $(cat "$OUTPUT_DIR/uname.txt")"
if [[ -f /etc/os-release ]]; then
    grep -E '^(PRETTY_NAME|VERSION_ID|BUILD_INFO|KERNEL)=' /etc/os-release 2>/dev/null \
        | tee "$OUTPUT_DIR/os-release.txt" || true
    while IFS= read -r line; do log "  $line"; done < "$OUTPUT_DIR/os-release.txt"
fi

section "2) BOOT ARGS (compare to factory chosen + smoke-test cmdline patches)"
cat /proc/cmdline | tee "$OUTPUT_DIR/kernel_cmdline.txt"
log "cmdline: $(cat "$OUTPUT_DIR/kernel_cmdline.txt")"
log ""
log "Parsed (for diff vs extraction):"
for key in console root earlycon storagemedia androidboot.storagemedia androidboot.mode; do
    val=$(cat "$OUTPUT_DIR/kernel_cmdline.txt" | tr ' ' '\n' | grep -E "^${key}=" | head -1 || true)
    log "  ${val:-$key=<not set>}"
done

section "3) ROOT DISK / PARTUUID (compare to factory_fresh/03_partitions/parameter.txt)"
lsblk -a -o NAME,SIZE,TYPE,MOUNTPOINT,PARTUUID,FSTYPE | tee "$OUTPUT_DIR/lsblk.txt"
log "$(cat "$OUTPUT_DIR/lsblk.txt")"
if command -v blkid >/dev/null 2>&1; then
    blkid | tee "$OUTPUT_DIR/blkid.txt"
    log ""
    log "blkid (root-related):"
    grep -E 'mmcblk|PARTUUID' "$OUTPUT_DIR/blkid.txt" | while read -r line; do log "  $line"; done
fi
df -hT | tee "$OUTPUT_DIR/df.txt" >/dev/null
log ""
log "mounts:"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/df.txt"

section "4) CONSOLE / SERIAL (critical: factory uses ttyFIQ0, not ttyS3)"
log "TTY devices present:"
ls -1 /dev/ttyFIQ* /dev/ttyS* /dev/console 2>/dev/null | tee "$OUTPUT_DIR/tty_devices.txt" || true
while read -r t; do log "  $t"; done < "$OUTPUT_DIR/tty_devices.txt" 2>/dev/null || log "  (none found)"
log ""
log "getty / serial services:"
if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --all 2>/dev/null \
        | grep -Ei 'serial|getty|fiq|console' \
        | tee "$OUTPUT_DIR/serial_services.txt" || true
    while read -r line; do log "  $line"; done < "$OUTPUT_DIR/serial_services.txt" 2>/dev/null || true
fi
log ""
log "Device-tree console-related nodes:"
log "  chosen/bootargs: $(dt_read chosen/bootargs)"
log "  chosen/stdout-path: $(dt_read chosen/stdout-path '<not set>')"
log "  fiq-debugger props:"
dt_find_prop 'rockchip,serial-id' | tee "$OUTPUT_DIR/dt_fiq_serial_id.txt" | while read -r line; do log "    $line"; done
dt_find_prop 'rockchip,baudrate'   | tee "$OUTPUT_DIR/dt_fiq_baudrate.txt"   | while read -r line; do log "    $line"; done
for uart in ff0a0000 ff0b0000 ff0c0000 ff0d0000 ff0e0000; do
    st=$(dt_read "serial@${uart}/status" "<no node>")
    log "  serial@${uart}/status: ${st}"
done

section "5) DMESG HIGHLIGHTS (console, root, mmc, fiq)"
dmesg > "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null || true
grep -Ei 'Machine model|command line|FIQ|fiq|ttyFIQ|ttyS|earlycon|console|PARTUUID|root|mmcblk|Mounted root|ext4-fs|dwmmc|resource\.img|bootargs' \
    "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null \
    | tee "$OUTPUT_DIR/dmesg_highlights.txt" || true
while read -r line; do log "$line"; done < "$OUTPUT_DIR/dmesg_highlights.txt" 2>/dev/null || true

section "6) MEMORY / CPU (compare to DTS memory@0)"
grep -E '^(processor|Serial|Hardware|Model)' /proc/cpuinfo | tee "$OUTPUT_DIR/proc_cpuinfo_snip.txt" >/dev/null
log "cpu/mem summary:"
head -5 "$OUTPUT_DIR/proc_cpuinfo_snip.txt" | while read -r line; do log "  $line"; done
grep -E '^(MemTotal|MemAvailable):' /proc/meminfo | tee "$OUTPUT_DIR/mem_snip.txt"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/mem_snip.txt"
log "  early mem from dmesg:"
grep -E 'Early memory|Memory:' "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null | head -3 | while read -r line; do log "  $line"; done

section "7) WIFI / MMC (factory DTS enables SDIO on mmc1)"
grep -Ei 'mmc[0-9]|sdio|8189|wifi|wlan' "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null \
    | head -30 | tee "$OUTPUT_DIR/dmesg_mmc_wifi.txt" >/dev/null
while read -r line; do log "$line"; done < "$OUTPUT_DIR/dmesg_mmc_wifi.txt" 2>/dev/null || true
lsmod | tee "$OUTPUT_DIR/lsmod.txt" >/dev/null
log "loaded modules (wifi-related):"
grep -Ei '8189|wifi|wlan|cfg80211|mac80211' "$OUTPUT_DIR/lsmod.txt" | while read -r line; do log "  $line"; done || log "  (none)"

section "8) GPIO (onboard + external header, WiFi reset, LCD/panel control)"
log "GPIO chips (/sys/class/gpio):"
if compgen -G "/sys/class/gpio/gpiochip*" >/dev/null; then
    for chip in /sys/class/gpio/gpiochip*; do
        base=$(cat "$chip/base" 2>/dev/null || echo "?")
        ngpio=$(cat "$chip/ngpio" 2>/dev/null || echo "?")
        label=$(cat "$chip/label" 2>/dev/null || echo "?")
        echo "$(basename "$chip") base=${base} ngpio=${ngpio} label=${label}" | tee -a "$OUTPUT_DIR/gpio_chips.txt"
        log "  $(tail -1 "$OUTPUT_DIR/gpio_chips.txt")"
    done
else
    log "  (no gpiochip nodes — kernel may use chardev GPIO only)"
fi

if command -v gpiodetect >/dev/null 2>&1; then
    log ""
    log "libgpiod chips:"
    gpiodetect 2>/dev/null | tee "$OUTPUT_DIR/gpiodetect.txt" || true
    while read -r line; do log "  $line"; done < "$OUTPUT_DIR/gpiodetect.txt" 2>/dev/null || true
    for chip in $(awk '{print $1}' "$OUTPUT_DIR/gpiodetect.txt" 2>/dev/null); do
        [[ "$chip" == gpiochip* ]] || continue
        log "  gpioinfo $chip (first 20 lines):"
        gpioinfo "$chip" 2>/dev/null | head -20 | tee -a "$OUTPUT_DIR/gpioinfo_${chip}.txt" \
            | while read -r line; do log "    $line"; done || true
    done
fi

log ""
log "Exported GPIO lines (legacy sysfs):"
if compgen -G "/sys/class/gpio/gpio[0-9]*" >/dev/null; then
    for g in /sys/class/gpio/gpio[0-9]*; do
        num=$(basename "$g")
        dir=$(cat "$g/direction" 2>/dev/null || echo "?")
        val=$(cat "$g/value" 2>/dev/null || echo "?")
        echo "${num} direction=${dir} value=${val}" | tee -a "$OUTPUT_DIR/gpio_exported.txt"
        log "  $(tail -1 "$OUTPUT_DIR/gpio_exported.txt")"
    done
else
    log "  (none exported)"
fi

if [[ -r /sys/kernel/debug/gpio ]]; then
    cp /sys/kernel/debug/gpio "$OUTPUT_DIR/debug_gpio.txt" 2>/dev/null || true
    log "debug GPIO: saved debug_gpio.txt ($(wc -l < "$OUTPUT_DIR/debug_gpio.txt" 2>/dev/null || echo 0) lines)"
    grep -Ei 'gpio-0|gpio-1|PA[0-7]|PB[0-7]|PC[0-7]|wifi|led|lcd|panel|vbus|reset|enable' \
        "$OUTPUT_DIR/debug_gpio.txt" 2>/dev/null | head -40 | tee "$OUTPUT_DIR/debug_gpio_snip.txt" >/dev/null
    log "  notable lines (LED/LCD/WiFi GPIO):"
    while read -r line; do log "    $line"; done < "$OUTPUT_DIR/debug_gpio_snip.txt" 2>/dev/null || true
else
    log "debug GPIO: skipped (run as root; needs debugfs)"
fi

log ""
log "Device-tree GPIO-related nodes:"
dt_find_prop 'gpios' | grep -Ei 'led|wifi|panel|backlight|vbus|reset|enable|touch|goodix|rgb|lcd' \
    | tee "$OUTPUT_DIR/dt_gpios.txt" | head -30 | while read -r line; do log "  $line"; done || true
dt_nodes_by_compatible 'gpio-leds' "$OUTPUT_DIR/dt_gpio_leds.txt"
log "  gpio-leds nodes:"
while read -r line; do log "    $line"; done < "$OUTPUT_DIR/dt_gpio_leds.txt" 2>/dev/null || log "    (none)"
grep -Ei 'green|blue|led|heartbeat|power' "$OUTPUT_DIR/dt_gpio_leds.txt" 2>/dev/null \
    | while read -r line; do log "    $line"; done || true

section "9) PWM (core regulator, LCD backlight, external RGB header)"
log "PWM sysfs (/sys/class/pwm):"
if compgen -G "/sys/class/pwm/pwmchip*" >/dev/null; then
    for chip in /sys/class/pwm/pwmchip*; do
        npwm=$(cat "$chip/npwm" 2>/dev/null || echo "?")
        echo "$(basename "$chip") npwm=${npwm}" | tee -a "$OUTPUT_DIR/pwm_chips.txt"
        log "  $(tail -1 "$OUTPUT_DIR/pwm_chips.txt")"
        for pw in "$chip"/pwm[0-9]*; do
            [[ -d "$pw" ]] || continue
            period=$(cat "$pw/period" 2>/dev/null || echo "?")
            duty=$(cat "$pw/duty_cycle" 2>/dev/null || echo "?")
            en=$(cat "$pw/enable" 2>/dev/null || echo "?")
            echo "    $(basename "$pw") period=${period} duty=${duty} enable=${en}" | tee -a "$OUTPUT_DIR/pwm_channels.txt"
            log "  $(tail -1 "$OUTPUT_DIR/pwm_channels.txt")"
        done
    done
else
    log "  (no pwmchip — PWM may be driver-only or disabled in DT)"
fi

log ""
log "Device-tree PWM nodes (factory: pwm8/9 okay for vdd_core + backlight):"
dt_node_status_list 'pwm@' "$OUTPUT_DIR/dt_pwm_nodes.txt"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/dt_pwm_nodes.txt" 2>/dev/null || true
dt_nodes_by_compatible 'pwm-regulator' "$OUTPUT_DIR/dt_pwm_regulator.txt"
log "  pwm-regulator (vdd_core):"
while read -r line; do log "    $line"; done < "$OUTPUT_DIR/dt_pwm_regulator.txt" 2>/dev/null || true
dt_nodes_by_compatible 'pwm-backlight' "$OUTPUT_DIR/dt_pwm_backlight.txt"
log "  pwm-backlight:"
while read -r line; do log "    $line"; done < "$OUTPUT_DIR/dt_pwm_backlight.txt" 2>/dev/null || true
dt_nodes_by_compatible 'pwm-leds' "$OUTPUT_DIR/dt_pwm_leds.txt"
log "  pwm-leds (external 3-pin RGB header — often disabled):"
while read -r line; do log "    $line"; done < "$OUTPUT_DIR/dt_pwm_leds.txt" 2>/dev/null || log "    (none — header may be unused)"

grep -Ei 'pwm|backlight|vdd_core|regulator' "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null \
    | head -25 | tee "$OUTPUT_DIR/dmesg_pwm.txt" >/dev/null
log ""
log "dmesg PWM/backlight/regulator:"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/dmesg_pwm.txt" 2>/dev/null || true

section "10) FRAMEBUFFER / RGB DISPLAY (VOP, panel, 480x272 FPC)"
log "DRM / framebuffer sysfs:"
if [[ -d /sys/class/drm ]]; then
    ls -la /sys/class/drm/ | tee "$OUTPUT_DIR/drm_sysfs.txt" >/dev/null
    while read -r line; do log "  $line"; done < "$OUTPUT_DIR/drm_sysfs.txt"
    for conn in /sys/class/drm/card*-*; do
        [[ -e "$conn" ]] || continue
        status=$(cat "$conn/status" 2>/dev/null || echo "?")
        enabled=$(cat "$conn/enabled" 2>/dev/null || echo "?")
        modes=$(cat "$conn/modes" 2>/dev/null | head -3 | tr '\n' '; ')
        log "  $(basename "$conn"): status=${status} enabled=${enabled} modes=${modes}"
    done
else
    log "  (no /sys/class/drm)"
fi

if [[ -d /sys/class/graphics/fb0 ]]; then
    log ""
    log "Legacy fb0:"
    for f in name bits_per_pixel stride virtual_size; do
        [[ -f /sys/class/graphics/fb0/$f ]] && log "  $f=$(cat /sys/class/graphics/fb0/$f 2>/dev/null)"
    done
    cat /sys/class/graphics/fb0/modes 2>/dev/null | tee "$OUTPUT_DIR/fb0_modes.txt" >/dev/null
    log "  modes: $(head -3 "$OUTPUT_DIR/fb0_modes.txt" 2>/dev/null | tr '\n' ' ')"
fi

log ""
log "Device-tree display nodes:"
for node in display-subsystem rgb vop@ff2e0000 panel backlight; do
    st=$(dt_read "${node}/status" "<no node>")
    log "  ${node}/status: ${st}"
done
dt_nodes_by_compatible 'simple-panel' "$OUTPUT_DIR/dt_panel.txt"
log "  simple-panel:"
while read -r line; do log "    $line"; done < "$OUTPUT_DIR/dt_panel.txt" 2>/dev/null || true
dt_find_prop 'enable-gpios' | grep -i panel | tee "$OUTPUT_DIR/dt_panel_gpios.txt" >/dev/null || true
dt_find_prop 'reset-gpios'  | grep -i panel | tee -a "$OUTPUT_DIR/dt_panel_gpios.txt" >/dev/null || true
while read -r line; do log "    panel GPIO: $line"; done < "$OUTPUT_DIR/dt_panel_gpios.txt" 2>/dev/null || true

grep -Ei 'rockchip-drm|rockchip-vop|rockchip,rk3308-rgb|simple-panel|backlight|fb0|drm|panel|rgb' \
    "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null \
    | tee "$OUTPUT_DIR/dmesg_display.txt" || true
log ""
log "dmesg display:"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/dmesg_display.txt" 2>/dev/null || true

section "11) LEDs (onboard green/blue, external +/- header, RGB header)"
log "LED class (/sys/class/leds):"
if compgen -G "/sys/class/leds/*" >/dev/null; then
    for led in /sys/class/leds/*; do
        name=$(basename "$led")
        bright=$(cat "$led/brightness" 2>/dev/null || echo "?")
        max=$(cat "$led/max_brightness" 2>/dev/null || echo "?")
        trig=$(cat "$led/trigger" 2>/dev/null | grep '\*' | tr -d '* ' || cat "$led/trigger" 2>/dev/null | head -1)
        default=$(cat "$led/default-state" 2>/dev/null || echo "?")
        color=$(cat "$led/multi_index" 2>/dev/null || cat "$led/color" 2>/dev/null || echo "-")
        line="${name} brightness=${bright}/${max} trigger=${trig} default=${default}"
        echo "$line" | tee -a "$OUTPUT_DIR/leds_sysfs.txt"
        log "  $line"
        # Heuristic labels for this board
        case "$name" in
            *green*|*power*) log "    ^ likely onboard GREEN / power LED (GPIO0_A6)" ;;
            *blue*|*heartbeat*|*user*) log "    ^ likely onboard BLUE / heartbeat LED (GPIO0_A5)" ;;
            *red*|*rgb*) log "    ^ likely external RGB header channel" ;;
        esac
    done
else
    log "  (no /sys/class/leds entries — LED drivers may be missing/disabled)"
fi

log ""
log "Device-tree LED nodes:"
dt_nodes_by_compatible 'gpio-leds' "$OUTPUT_DIR/dt_leds_gpio.txt"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/dt_leds_gpio.txt" 2>/dev/null || true
grep -Ei 'green|blue|led' "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null | head -15 \
    | tee "$OUTPUT_DIR/dmesg_led.txt" >/dev/null
log "dmesg LED:"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/dmesg_led.txt" 2>/dev/null || true

section "12) OTHER DEVICES (I2C touch, SPI, USB, audio, platform)"
log "Platform devices (sample):"
ls /sys/bus/platform/devices 2>/dev/null | grep -Ei 'vop|rgb|drm|pwm|gpio|led|panel|backlight|acodec|i2s|touch|goodix|usb|dwmmc|fiq' \
    | tee "$OUTPUT_DIR/platform_devices.txt" || true
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/platform_devices.txt" 2>/dev/null || true

log ""
log "I2C devices (GT911 touch on i2c3 @ 0x5d in Armbian DTS):"
if [[ -d /sys/bus/i2c/devices ]]; then
    ls -la /sys/bus/i2c/devices/ | tee "$OUTPUT_DIR/i2c_devices.txt" >/dev/null
    while read -r line; do log "  $line"; done < "$OUTPUT_DIR/i2c_devices.txt"
    for dev in /sys/bus/i2c/devices/*-005d /sys/bus/i2c/devices/*-005D; do
        [[ -e "$dev" ]] || continue
        name=$(cat "$dev/name" 2>/dev/null || basename "$dev")
        log "  touch candidate: $name @ $(basename "$dev")"
    done
fi

log ""
log "Input devices (touchscreen / keys):"
if [[ -d /sys/class/input ]]; then
    for inp in /sys/class/input/input*/; do
        [[ -d "$inp" ]] || continue
        name=$(cat "${inp}name" 2>/dev/null || echo "?")
        phys=$(cat "${inp}phys" 2>/dev/null || echo "?")
        echo "$(basename "${inp%/}"): name=${name} phys=${phys}" | tee -a "$OUTPUT_DIR/input_devices.txt"
        log "  $(tail -1 "$OUTPUT_DIR/input_devices.txt")"
    done
fi

grep -Ei 'goodix|gt911|touch|input|acodec|i2s|usb|dwmmc|8189' "$OUTPUT_DIR/dmesg_full.txt" 2>/dev/null \
    | head -35 | tee "$OUTPUT_DIR/dmesg_devices.txt" >/dev/null
log ""
log "dmesg devices (touch/audio/usb):"
while read -r line; do log "  $line"; done < "$OUTPUT_DIR/dmesg_devices.txt" 2>/dev/null || true

section "13) PINCTRL (pin mux for UART/RGB/LED — needs root + debugfs)"
if [[ -d /sys/kernel/debug/pinctrl ]]; then
    for pdir in /sys/kernel/debug/pinctrl/*/; do
        [[ -d "$pdir" ]] || continue
        base=$(basename "$pdir")
        for f in pins pingroups pinmux-functions; do
            [[ -r "${pdir}${f}" ]] && cp "${pdir}${f}" "$OUTPUT_DIR/pinctrl_${base}_${f}.txt" 2>/dev/null || true
        done
        log "pinctrl ${base}: saved pins/pingroups/pinmux-functions"
    done
    grep -Ei 'uart|rgb|lcd|led|pwm|i2c|spi|touch|wifi|sdio' "$OUTPUT_DIR"/pinctrl_*pins*.txt 2>/dev/null \
        | head -40 | tee "$OUTPUT_DIR/pinctrl_snip.txt" >/dev/null || true
    log "  notable pin functions:"
    while read -r line; do log "    $line"; done < "$OUTPUT_DIR/pinctrl_snip.txt" 2>/dev/null || true
else
    log "pinctrl: skipped (run as root; needs debugfs mounted)"
fi

section "14) CHECKLIST — compare to factory_fresh + dts/rk3308bs-evb-amic-v11.dts"
log "Boot / console:"
log "  [ ] model = RK3308B-S evb analog mic v11"
log "  [ ] console=ttyFIQ0 (factory) — not ttyS3 unless DT disables fiq-debugger"
log "  [ ] root=PARTUUID=614e0000-0000 on mmcblk0p6"
log ""
log "GPIO / LEDs (board-specific):"
log "  [ ] green-led / power LED on GPIO0_A6 (default-on)"
log "  [ ] blue-led / heartbeat on GPIO0_A5 (shared with spk-ctl in OEM DT)"
log "  [ ] external LED +/- header uses same GPIOs as onboard leds"
log "  [ ] 3-pin RGB header: pwm-leds often DISABLED in factory (check dt_pwm_leds.txt)"
log ""
log "PWM:"
log "  [ ] pwm@ff180000 (PWM8) okay — CPU vdd_core regulator"
log "  [ ] pwm@ff180010 (PWM9) okay — LCD backlight"
log "  [ ] pwm@ff160000–ff170030 mostly disabled in factory"
log ""
log "Display:"
log "  [ ] vop@ff2e0000 + rgb status okay"
log "  [ ] panel + backlight status okay"
log "  [ ] dmesg: rockchip-drm initialized, fb0 ~480x272"
log "  [ ] panel enable GPIO1_A3, reset GPIO0_C4"
log ""
log "If LEDs/display work on factory but fail after Armbian flash,"
log "compare sections 8–11 against your Armbian DTS (pinctrl, &rgb, &pwm8/9, leds)."

section "DONE"
log "Files written under: $(pwd)/${OUTPUT_DIR}/"
log "Key files: REPORT.txt, leds_sysfs.txt, drm_sysfs.txt, dt_pwm_nodes.txt,"
log "           dt_panel.txt, debug_gpio.txt, pinctrl_* (if root)"
log "Send back: REPORT.txt (minimum) or: tar czf rk3308_factory_audit.tgz ${OUTPUT_DIR}/"

echo ""
echo "Audit complete. Read ${OUTPUT_DIR}/REPORT.txt first."

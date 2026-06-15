#!/bin/bash
# Factory firmware LED audit ? software flow + pinmux + pin test helpers
# Run on board after factory flash: sh factory-led-audit.sh
set -euo pipefail
OUT="${1:-/root/factory_led_audit}"
mkdir -p "$OUT"
log() { echo "[factory-led-audit] $*"; }

log "output -> $OUT"

{
  echo "=== IDENTITY ==="
  uname -a
  cat /etc/os-release 2>/dev/null || true
  cat /proc/device-tree/model 2>/dev/null | tr -d '\0'; echo
} > "$OUT/identity.txt"

{
  echo "=== CMDLINE ==="
  cat /proc/cmdline
} > "$OUT/cmdline.txt"

{
  echo "=== LEDS SYSFS ==="
  ls -laR /sys/class/leds/ 2>/dev/null || echo "(none)"
  for led in /sys/class/leds/*; do
    [[ -d "$led" ]] || continue
    echo "--- $led ---"
    for f in brightness max_brightness trigger uevent; do
      [[ -f "$led/$f" ]] && echo "$f=$(cat "$led/$f" 2>/dev/null)"
    done
  done
} > "$OUT/leds_sysfs.txt"

{
  echo "=== PWM SYSFS ==="
  ls -laR /sys/class/pwm/ 2>/dev/null || echo "(none)"
} > "$OUT/pwm_sysfs.txt"

if [[ -r /sys/kernel/debug/pwm ]]; then
  cp /sys/kernel/debug/pwm "$OUT/pwm_debug.txt" 2>/dev/null || cat /sys/kernel/debug/pwm > "$OUT/pwm_debug.txt"
fi

if [[ -r /sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins ]]; then
  cp /sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins "$OUT/pinmux-pins.txt"
fi

{
  echo "=== GPIO CHIPS ==="
  ls -la /dev/gpiochip* 2>/dev/null || true
  for c in /dev/gpiochip*; do
    echo "--- $c ---"
    gpioinfo "$c" 2>/dev/null || true
  done
} > "$OUT/gpioinfo.txt"

{
  echo "=== DEVICE TREE LED/PWM NODES ==="
  find /sys/firmware/devicetree -maxdepth 4 \( -name '*led*' -o -name '*pwm*' -o -name '*rgb*' -o -name '*light*' \) 2>/dev/null | sort
  for n in lightbar leds rgb-leds rgb_leds pwm-leds; do
    p="/sys/firmware/devicetree/base/$n"
    [[ -d "$p" ]] && find "$p" -type f 2>/dev/null | while read -r f; do
      printf "%s: " "$f"
      tr -d '\0' < "$f" 2>/dev/null; echo
    done
  done
} > "$OUT/dt_led_pwm.txt" 2>&1

{
  echo "=== CONFIG GREP (led/rgb/ws281/pebble/lightbar) ==="
  grep -rniE 'ws281|neopixel|pebble|lightbar|rgb.s|rgb-s|led_strip|pwm.led|gpio0|gpiochip' \
    /etc /opt /home /root /usr/local 2>/dev/null | head -200 || true
} > "$OUT/config_grep.txt"

{
  echo "=== SYSTEMD LED-RELATED ==="
  systemctl list-units --all 2>/dev/null | grep -iE 'led|rgb|light|klip|print' || true
  ls -la /lib/systemd/system/*led* /lib/systemd/system/*rgb* /lib/systemd/system/*light* 2>/dev/null || true
} > "$OUT/systemd.txt"

{
  echo "=== PROCESSES ==="
  ps aux 2>/dev/null | grep -iE 'led|rgb|klip|moon|print|light' | grep -v grep || true
} > "$OUT/processes.txt"

{
  echo "=== DMESG LED/PWM ==="
  dmesg 2>/dev/null | grep -iE 'led|pwm|lightbar|rgb|ws281' || true
} > "$OUT/dmesg_led.txt"

{
  echo "=== LOADED MODULES ==="
  lsmod
} > "$OUT/lsmod.txt"

{
  echo "=== BINARY STRINGS HINTS ==="
  for bin in /usr/bin/* /usr/sbin/*; do
    [[ -f "$bin" && -x "$bin" ]] || continue
    if strings "$bin" 2>/dev/null | grep -qiE 'ws281|neopixel|lightbar|rgb.s|pebble|led_strip'; then
      echo "HIT: $bin"
    fi
  done
} > "$OUT/binary_hits.txt" 2>&1

cat > "$OUT/PIN_TEST_PLAN.txt" << 'EOF'
Factory pin test plan (one at a time, DMM on header)

RGB header (5V G S): measure S to G
+LED- header: measure LED+ to LED-

Priority candidates from RK3308 ball map:
  gpiochip0 line 13  GPIO0_B5  PWM0   (+LED- lightbar)
  gpiochip2 line 10  GPIO2_A10 PWM8   (factory DTB wrong mux)
  gpiochip0 line 1   GPIO0_A1  PWM4   (old RGB guess)
  gpiochip2 line 5   SPI1 MOSI m1     (WS2812 SPI guess)
  gpiochip3 line 12  SPI1 MOSI default

Run toggle (5s high / 5s low, 45s):
  sh /usr/local/sbin/gpio-dmm-probe.sh gpiochip0 LINE 45 5

After software discovery: trigger factory UI LED test if found in config_grep.txt
EOF

log "done -> $OUT"
log "review: config_grep.txt dt_led_pwm.txt pinmux-pins.txt PIN_TEST_PLAN.txt"

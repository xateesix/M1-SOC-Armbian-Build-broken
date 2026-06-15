#!/usr/bin/env bash
# Set white LED light bar to PWM brightness (0-255 or percent).
set -euo pipefail
LED=/sys/class/leds/lightbar:white
if [[ ! -d "$LED" ]]; then
  echo "ERROR: $LED not found — flash v62 boot DTB and: modprobe leds-pwm"
  exit 1
fi
modprobe leds-pwm 2>/dev/null || true
echo none > "$LED/trigger"
BR="${1:-100}"
if [[ "$BR" == *%* ]]; then
  BR="${BR%%%}"
  MAX=$(cat "$LED/max_brightness")
  BR=$(( MAX * BR / 100 ))
fi
echo "$BR" > "$LED/brightness"
echo "lightbar brightness=$(cat $LED/brightness)/$(cat $LED/max_brightness)"

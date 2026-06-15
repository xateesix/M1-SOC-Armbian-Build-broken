#!/usr/bin/env bash
# Artillery M1 Pro SOC (RK3308BS)  -  onboard GPIO LEDs + 3-pin RGB header test.
set -euo pipefail

GREEN_LED=/sys/class/leds/rockpis:green:power
BLUE_LED=/sys/class/leds/rockpis:blue:user
CHIP=gpiochip0
RGB_R=1    # GPIO0_A1 / PWM4
RGB_G=17   # gpio0-17 / PWM5
RGB_B=18   # gpio0-18 / PWM6

say() { echo; echo ">>> $*"; }

restore_leds() {
  echo none > "$GREEN_LED/trigger" 2>/dev/null || true
  echo default-on > "$GREEN_LED/trigger" 2>/dev/null || true
  echo none > "$BLUE_LED/trigger" 2>/dev/null || true
  echo heartbeat > "$BLUE_LED/trigger" 2>/dev/null || true
}

rgb_off() {
  gpioset "$CHIP" $RGB_R=0 $RGB_G=0 $RGB_B=0 2>/dev/null || true
}

cleanup() {
  rgb_off
  restore_leds
}
trap cleanup EXIT

if [ ! -d "$GREEN_LED" ]; then
  echo "ERROR: $GREEN_LED not found  -  gpio-leds missing from DTB"
  exit 1
fi

if ! command -v gpioset >/dev/null; then
  echo "ERROR: gpioset not found (install gpiod)"
  exit 1
fi

say "PART 1: Onboard GPIO LEDs (green=power GPIO0_A6, blue=user GPIO0_A5)"
echo none > "$GREEN_LED/trigger"
echo none > "$BLUE_LED/trigger"

for step in "1 0 green on" "0 1 blue on" "1 1 both on" "0 0 both off"; do
  set -- $step
  echo $1 > "$GREEN_LED/brightness"
  echo $2 > "$BLUE_LED/brightness"
  say "$3 $4 (3s)"
  sleep 3
done

say "PART 2: 3-pin RGB header via GPIO (R=$RGB_R G=$RGB_G B=$RGB_B)"
say "PWM4/5/6 are disabled in DT  -  testing digital on/off only"
rgb_off

for color in "1 0 0 RED" "0 1 0 GREEN" "0 0 1 BLUE" "1 1 1 WHITE" "0 0 0 OFF"; do
  set -- $color
  gpioset "$CHIP" $RGB_R=$1 $RGB_G=$2 $RGB_B=$3
  say "RGB $4 (3s)"
  sleep 3
done

say "PART 3: RGB channels one at a time (longer)"
for line in "$RGB_R:red" "$RGB_G:green" "$RGB_B:blue"; do
  IFS=: read -r pin name <<< "$line"
  rgb_off
  gpioset "$CHIP" $pin=1
  say "only $name channel (5s)"
  sleep 5
done
rgb_off

say "DONE  -  restored default LED triggers (green=on, blue=heartbeat)"
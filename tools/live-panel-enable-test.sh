#!/bin/bash
set -e
echo "=== RK3308BS live panel enable test ==="
echo 0 > /sys/class/graphics/fb0/blank
echo 255 > /sys/class/backlight/backlight/brightness
echo 0 > /sys/class/backlight/backlight/bl_power
echo panel > /sys/bus/platform/drivers/panel-simple/unbind 2>/dev/null || true
echo 35 > /sys/class/gpio/unexport 2>/dev/null || true
echo 35 > /sys/class/gpio/export
echo 1 > /sys/class/gpio/gpio35/active_low
echo out > /sys/class/gpio/gpio35/direction
echo 1 > /sys/class/gpio/gpio35/value
dd if=/dev/zero bs=4096 count=32 of=/dev/fb0 2>/dev/null || true
echo "GPIO:"; grep gpio-3 /sys/kernel/debug/gpio || true
echo "fb blank=$(cat /sys/class/graphics/fb0/blank)"
echo "=== DONE - check LCD ==="

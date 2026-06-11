#!/bin/bash
set -euo pipefail
REL="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian/releases/1.0.0"
F="$REL/_board-kernel.dtb"
echo "=== tsadc ==="
fdtget -l "$F" /tsadc 2>&1 || true
fdtget "$F" /tsadc status 2>&1 || true
fdtget "$F" /tsadc pinctrl-0 2>&1 || echo "no pinctrl-0"
fdtget "$F" /tsadc rockchip,hw-tshut-mode 2>&1 || true
echo "=== otp ==="
fdtget -l "$F" /otp 2>&1 || echo "no otp node"
echo "=== opp tables ==="
fdtget -l "$F" / 2>&1 | grep -E 'opp|thermal' || true
fdtget "$F" /cpus/cpu@0 operating-points-v2 2>&1 || true

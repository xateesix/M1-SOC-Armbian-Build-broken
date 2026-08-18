#!/bin/bash
set -euo pipefail
REL="$PROJECT_ROOT/output/releases/1.0.0"
for label in factory board; do
  echo "=== $label ==="
  F="$REL/_${label}-kernel.dtb"
  fdtget -l "$F" /thermal-zones/soc-thermal/trips 2>&1 || true
  fdtget "$F" /thermal-zones/soc-thermal/trips/soc-crit temperature 2>&1 || echo "no soc-crit"
  fdtget "$F" /tsadc rockchip,hw-tshut-temp 2>&1 || echo "no hw-tshut-temp"
  fdtget "$F" / model 2>&1 || true
  fdtget "$F" /chosen bootargs 2>&1 | head -c 120 || true
  echo
done

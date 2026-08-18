#!/bin/bash
REL="$PROJECT_ROOT/output/releases/1.0.0"
ls -la "$REL"/_fac-dtb-v*.dtb 2>&1
for f in "$REL"/_fac-dtb-v16.dtb "$REL"/_fac-dtb-v39.dtb; do
  [[ -f "$f" ]] && echo "SIZE $(basename "$f"): $(wc -c < "$f")"
done
fdtget "$REL/_fac-dtb-v39.dtb" /panel compatible
fdtget "$REL/_fac-dtb-v39.dtb" /panel/panel-timing hactive
fdtget "$REL/_fac-dtb-v39.dtb" /panel/display-timings native-mode 2>&1 || echo "display-timings deleted OK"

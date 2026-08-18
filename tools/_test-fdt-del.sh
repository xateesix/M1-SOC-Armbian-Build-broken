#!/bin/bash
REL="$PROJECT_ROOT/output/releases/1.0.0"
cp "$REL/_fac-dtb-v39.dtb" /tmp/test.dtb
echo "before: $(wc -c < /tmp/test.dtb)"
fdtput -d /tmp/test.dtb /panel/display-timings
echo "after delete: $(wc -c < /tmp/test.dtb)"
fdtget /tmp/test.dtb /panel/display-timings native-mode 2>&1 || echo "deleted OK"

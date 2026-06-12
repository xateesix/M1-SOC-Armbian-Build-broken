#!/bin/bash
set -euo pipefail
REPO="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian"
PANEL=drivers/gpu/drm/panel/panel-simple.c
cd ~/linux-v13-build
git checkout -f v6.18
python3 "$REPO/tools/gen-panel-simple-patch.py"
patch -p1 --forward < "$REPO/patches/0006-panel-dpi-bus-format.patch"
cp "$PANEL" /tmp/panel-after-0006.c
python3 "$REPO/tools/gen-patch-0007.py"
diff -u /tmp/panel-after-0006.c "$PANEL" | sed '1s|--- /tmp/panel-after-0006.c|--- a/drivers/gpu/drm/panel/panel-simple.c|;2s|+++ .*panel-simple.c|+++ b/drivers/gpu/drm/panel/panel-simple.c|' > "$REPO/patches/0007-panel-dpi-probe-complete.patch"
echo "lines: $(wc -l < "$REPO/patches/0007-panel-dpi-probe-complete.patch")"
# verify
git checkout -f v6.18
python3 "$REPO/tools/gen-panel-simple-patch.py"
patch -p1 --forward < "$REPO/patches/0006-panel-dpi-bus-format.patch"
patch -p1 --forward < "$REPO/patches/0007-panel-dpi-probe-complete.patch"
grep -q 'panel-simple registered' "$PANEL"
echo OK

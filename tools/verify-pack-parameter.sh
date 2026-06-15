#!/usr/bin/env bash
set -euo pipefail
PARAM="${1:?parameter.txt path}"
line=$(grep '^CMDLINE:' "$PARAM")
echo "$line"
echo "$line" | grep -qE '0x[0-9a-fA-F]+@0x00017200\(rootfs\)' || { echo "FAIL: need explicit size@(rootfs) at 0x17200"; exit 1; }
echo "$line" | grep -q 'rootfs:grow' && { echo "FAIL: rootfs:grow causes RKDevTool to skip rootfs write"; exit 1; }
echo "$line" | grep -qE ',\-@0x00017200' && { echo "FAIL: grow-only skips rootfs"; exit 1; }
grep -q 'uuid:rootfs=614e0000' "$PARAM" || { echo "FAIL: missing uuid:rootfs"; exit 1; }
echo "OK: explicit (rootfs) @0x17200"

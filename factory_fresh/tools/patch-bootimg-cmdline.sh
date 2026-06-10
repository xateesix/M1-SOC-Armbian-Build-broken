#!/usr/bin/env bash
# Copy a Rockchip boot.img and patch the 512-byte cmdline field (default offset 0x50).
# Factory images keep LZ4 kernel + resource.img intact — do NOT use mkbootimg here.
set -euo pipefail

SRC="${1:?usage: patch-bootimg-cmdline.sh SRC.img DST.img \"cmdline\" [offset]}"
DST="${2:?}"
CMDLINE="${3:?}"
OFFSET="${4:-0x50}"

python3 - "$SRC" "$DST" "$CMDLINE" "$OFFSET" <<'PY'
import sys
src, dst, cmdline, offset_s = sys.argv[1:5]
offset = int(offset_s, 0)
size = 512
with open(src, "rb") as f:
    data = bytearray(f.read())
if offset + size > len(data):
    raise SystemExit(f"cmdline region {offset:#x}+{size} exceeds boot.img size {len(data)}")
payload = cmdline.encode("ascii", errors="strict")
if len(payload) >= size:
    raise SystemExit(f"cmdline too long ({len(payload)} bytes, max {size - 1})")
data[offset:offset + size] = payload + b"\x00" * (size - len(payload))
with open(dst, "wb") as f:
    f.write(data)
print(f"Patched {dst} @ {offset:#x}: {cmdline}")
PY

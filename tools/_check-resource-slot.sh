#!/bin/bash
FAC="$PROJECT_ROOT/output/factory_fresh/04_boot_unpacked/resource.img"
REL="$PROJECT_ROOT/output/releases/1.0.0"
python3 <<'PY'
import struct
from pathlib import Path
data = Path("$PROJECT_ROOT/output/factory_fresh/04_boot_unpacked/resource.img").read_bytes()
magic = b"\xd0\x0d\xfe\xed"
idx = data.find(magic)
totalsize = struct.unpack(">I", data[idx+4:idx+8])[0]
print(f"resource.img total: {len(data)}")
print(f"FDT @ {idx:#x} totalsize field: {totalsize}")
slot_end = idx + totalsize
zeros = 0
while slot_end < len(data) and data[slot_end] == 0 and (slot_end - idx) <= 65536:
    slot_end += 1
    zeros += 1
print(f"slot with zero pad: {slot_end - idx} (extra zeros: {zeros})")
print(f"v16 dtb: {(Path('$PROJECT_ROOT/output/releases/1.0.0/_fac-dtb-v16.dtb')).stat().st_size}")
print(f"v39 dtb: {(Path('$PROJECT_ROOT/output/releases/1.0.0/_fac-dtb-v39.dtb')).stat().st_size}")
PY

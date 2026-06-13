#!/usr/bin/env bash
# Remove duplicate flash/rootfs artifacts; keep what v45 rebuild needs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"

[[ -d "$REL" ]] || { echo "Missing $REL"; exit 1; }

echo "=== RK3308BS release cleanup ==="
echo "Before:"
du -sh "$REL" "$SCRIPT_DIR"/.build-* "$SCRIPT_DIR"/.wsl-tmp 2>/dev/null || true

# Intermediate pack staging (keep latest v39 only)
rm -rf "$REL/pack_input" "$REL/pack_input_v16"

# Old boot/resource intermediates (keep v39)
for v in 8 9 10 11 12 13 14 15 16; do
	rm -f "$REL/_boot-v${v}.img" "$REL/_resource-v${v}.img"
done
rm -f "$REL/_boot-fixed-dtbhash.img" "$REL/boot.img" "$REL/boot-fixed-header.img"
rm -f "$REL/_uboot_patched_test.img" "$REL/firmware.img"

# Old full firmware images (keep v42 rollback + v43 latest)
for v in $(seq 21 41); do
	rm -f "$REL/rk3308bs-1.0.0-emmc-fixed-v${v}.img"
done

# Duplicate rootfs intermediates (keep v11 base + v43 latest)
for v in $(seq 24 42); do
	rm -f "$REL/rootfs-v${v}.img"
done

# WSL build temps
rm -rf "$SCRIPT_DIR"/.build-v* "$SCRIPT_DIR"/.wsl-tmp/btt-build

# Accidental junk from bad shell redirects
rm -f "$SCRIPT_DIR"/I,data* 2>/dev/null || true

echo
echo "After:"
du -sh "$REL" "$SCRIPT_DIR"/.wsl-tmp 2>/dev/null || true
echo
echo "Kept for rebuild/flash:"
ls -lh "$REL"/rootfs-v11.img "$REL"/rootfs-v43.img 2>/dev/null || true
ls -lh "$REL"/rk3308bs-1.0.0-emmc-fixed-v4*.img "$REL"/rk3308bs-1.0.0-emmc-fixed.img 2>/dev/null || true
ls -lh "$REL"/_Image-v22 "$REL"/_boot-v39.img "$REL"/_resource-v39.img 2>/dev/null || true
echo "DONE"

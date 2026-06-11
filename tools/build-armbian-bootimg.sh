#!/usr/bin/env bash
# Phase B: build Rockchip boot.img from Armbian Image + DTB (LZ4 kernel, resource.img DTB slot).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

ARMBIAN_IMG=""
IMAGE=""
DTB=""
OUT_BOOT=""
FACTORY_DIR="${FACTORY_DIR:-$REPO/factory_fresh/03_partitions}"
RESOURCE_TEMPLATE="${RESOURCE_TEMPLATE:-$REPO/factory_fresh/04_boot_unpacked/resource.img}"
CONSOLE="${CONSOLE:-ttyS3,1500000n8}"
ROOT_UUID=""
CMDLINE_EXTRA=""

usage() {
    cat <<EOF
Usage: build-armbian-bootimg.sh --out boot.img [options]

Options:
  --armbian PATH       Armbian .img (extracts Image + DTB automatically)
  --image PATH         Uncompressed kernel Image (from Armbian build)
  --dtb PATH           Board .dtb (default: rk3308bs-evb-amic-v11.dtb)
  --out PATH           Output boot.img (required)
  --factory DIR        Factory 03_partitions (for resource template fallback)
  --resource PATH      resource.img template (default: 04_boot_unpacked/resource.img)
  --console STR        Linux console= (default: ttyS3,1500000n8)
  --root-uuid UUID     root=PARTUUID= for cmdline
  --cmdline-extra STR  Append to generated cmdline

Requires: lz4, python3, sudo (if using --armbian)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --armbian) ARMBIAN_IMG="$2"; shift 2 ;;
        --image) IMAGE="$2"; shift 2 ;;
        --dtb) DTB="$2"; shift 2 ;;
        --out) OUT_BOOT="$2"; shift 2 ;;
        --factory) FACTORY_DIR="$2"; shift 2 ;;
        --resource) RESOURCE_TEMPLATE="$2"; shift 2 ;;
        --console) CONSOLE="$2"; shift 2 ;;
        --root-uuid) ROOT_UUID="$2"; shift 2 ;;
        --cmdline-extra) CMDLINE_EXTRA="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown: $1"; usage; exit 1 ;;
    esac
done

[[ -n "$OUT_BOOT" ]] || { usage; exit 1; }

if [[ -n "$ARMBIAN_IMG" ]]; then
    ART_DIR="$(mktemp -d)"
    bash "$SCRIPT_DIR/extract-armbian-boot-artifacts.sh" "$ARMBIAN_IMG" "$ART_DIR"
    IMAGE="$ART_DIR/Image"
    DTB="$ART_DIR/$(basename "${DTB:-rk3308bs-evb-amic-v11.dtb}")"
    if [[ ! -f "$DTB" ]]; then
        DTB="$ART_DIR/rk3308bs-evb-amic-v11.dtb"
    fi
fi

[[ -f "$IMAGE" ]] || { echo "Missing kernel Image: $IMAGE"; exit 1; }
[[ -f "$DTB" ]] || { echo "Missing DTB: $DTB"; exit 1; }

if [[ ! -f "$RESOURCE_TEMPLATE" && -f "$FACTORY_DIR/../04_boot_unpacked/resource.img" ]]; then
    RESOURCE_TEMPLATE="$FACTORY_DIR/../04_boot_unpacked/resource.img"
fi
if [[ ! -f "$RESOURCE_TEMPLATE" ]]; then
    echo "Missing resource.img template. Run: cd factory_fresh && ./unpack-boot.sh"
    exit 1
fi

command -v lz4 >/dev/null || { echo "Install lz4"; exit 1; }

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

LZ4_KERNEL="$WORKDIR/kernel.lz4"
echo "=== LZ4 compress kernel ==="
# Rockchip U-Boot accepts standard LZ4 frame (same as factory boot.img kernel slot)
lz4 -f -9 "$IMAGE" "$LZ4_KERNEL"
file "$LZ4_KERNEL"

RESOURCE="$WORKDIR/resource.img"
echo "=== Patch DTB bootargs (U-Boot passes these to Linux, not boot.img cmdline) ==="
PATCHED_DTB="$WORKDIR/board.dtb"
python3 "$SCRIPT_DIR/patch-dtb-bootargs.py" \
    --dtb "$DTB" \
    --output "$PATCHED_DTB" \
    --console "$CONSOLE" \
    ${ROOT_UUID:+--root-uuid "$ROOT_UUID"}

echo "=== Pack resource.img with custom DTB ==="
python3 "$SCRIPT_DIR/pack-resource-img.py" \
    --template "$RESOURCE_TEMPLATE" \
    --dtb "$PATCHED_DTB" \
    --output "$RESOURCE"

if [[ -z "$ROOT_UUID" && -f "$FACTORY_DIR/parameter.txt" ]]; then
    ROOT_UUID=$(grep -E '^uuid:rootfs=' "$FACTORY_DIR/parameter.txt" | cut -d= -f2- || true)
fi

CMDLINE="earlycon=uart8250,mmio32,0xff0d0000 console=${CONSOLE} loglevel=7"
if [[ -n "$ROOT_UUID" ]]; then
    CMDLINE+=" root=PARTUUID=${ROOT_UUID} rootfstype=ext4 rw rootwait"
else
    CMDLINE+=" root=/dev/mmcblk0p6 rootfstype=ext4 rw rootwait"
fi
[[ -n "$CMDLINE_EXTRA" ]] && CMDLINE+=" $CMDLINE_EXTRA"

echo "=== Assemble boot.img ==="
echo "cmdline: $CMDLINE"
python3 "$SCRIPT_DIR/pack-rockchip-bootimg.py" \
    --kernel "$LZ4_KERNEL" \
    --resource "$RESOURCE" \
    --output "$OUT_BOOT" \
    --cmdline "$CMDLINE"

echo "Done: $OUT_BOOT ($(wc -c < "$OUT_BOOT") bytes)"

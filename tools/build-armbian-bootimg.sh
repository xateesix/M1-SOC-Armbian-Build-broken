#!/usr/bin/env bash
# Phase B: build Rockchip boot.img from Armbian Image + DTB (LZ4 kernel, resource.img DTB slot).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

ARMBIAN_IMG=""
IMAGE=""
DTB=""
DTB_SOURCE="${DTB_SOURCE:-$REPO/dts/rk3308bs-evb-amic-v11.dts}"
OUT_BOOT=""
FACTORY_DIR="${FACTORY_DIR:-$REPO/factory_fresh/03_partitions}"
RESOURCE_TEMPLATE="${RESOURCE_TEMPLATE:-$REPO/factory_fresh/04_boot_unpacked/resource.img}"
BOOT_LOGO="${BOOT_LOGO:-$REPO/Media/boot-logo-artillery.bmp}"
CONSOLE="${CONSOLE:-ttyS3,1500000n8}"
ROOT_UUID=""
CMDLINE_EXTRA=""
DISABLE_THERMAL_CRITICAL="${DISABLE_THERMAL_CRITICAL:-0}"
DISABLE_TSADC="${DISABLE_TSADC:-0}"
RK3308BS_TSADC="${RK3308BS_TSADC:-0}"
GOODIX_FACTORY_DEFAULTS="${GOODIX_FACTORY_DEFAULTS:-0}"
FORCE_ARMBIAN_SERIAL_FALLBACK="${FORCE_ARMBIAN_SERIAL_FALLBACK:-1}"
ROOT_DELAY="${ROOT_DELAY:-5}"
SYSTEMD_COLOR="${SYSTEMD_COLOR:-never}"

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
    --logo PATH          Boot logo BMP (default: Media/boot-logo-artillery.bmp)
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
        --logo) BOOT_LOGO="$2"; shift 2 ;;
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
PATCH_ARGS=(
    --output "$PATCHED_DTB"
    --console "$CONSOLE"
)
if [[ -f "$DTB_SOURCE" ]]; then
       PATCH_ARGS+=(--dts "$DTB_SOURCE")
fi
if [[ -n "$ROOT_UUID" ]]; then
    PATCH_ARGS+=(--root-uuid "$ROOT_UUID")
fi
if [[ "$DISABLE_THERMAL_CRITICAL" == "1" ]]; then
    PATCH_ARGS+=(--disable-thermal-critical)
fi
if [[ "$DISABLE_TSADC" == "1" ]]; then
    PATCH_ARGS+=(--disable-tsadc)
fi
if [[ "$RK3308BS_TSADC" == "1" ]]; then
    PATCH_ARGS+=(--rk3308bs-tsadc)
fi
if [[ "$GOODIX_FACTORY_DEFAULTS" == "1" ]]; then
    PATCH_ARGS+=(--goodix-factory-defaults)
fi

python3 "$SCRIPT_DIR/patch-dtb-bootargs.py" \
    --dtb "$DTB" \
    "${PATCH_ARGS[@]}"

echo "=== Pack resource.img with custom DTB ==="
RESOURCE_LOGO="$WORKDIR/resource-logo.img"
if ! python3 "$SCRIPT_DIR/pack-resource-img.py" \
    --template "$RESOURCE_TEMPLATE" \
    --dtb "$PATCHED_DTB" \
    --output "$RESOURCE"; then
    echo "[WARN] Armbian DTB did not fit resource slot. Falling back to factory DTB with updated bootargs."
    FALLBACK_ARGS=()
    if [[ "$FORCE_ARMBIAN_SERIAL_FALLBACK" == "1" ]]; then
        FALLBACK_ARGS+=(--armbian-serial)
    fi
    python3 "$SCRIPT_DIR/patch-dtb-bootargs.py" \
        --from-factory-resource "$RESOURCE_TEMPLATE" \
        "${FALLBACK_ARGS[@]}" \
        "${PATCH_ARGS[@]}"
    python3 "$SCRIPT_DIR/pack-resource-img.py" \
        --template "$RESOURCE_TEMPLATE" \
        --dtb "$PATCHED_DTB" \
        --output "$RESOURCE"
fi

if [[ -f "$BOOT_LOGO" ]]; then
    echo "=== Patch boot logo into resource.img ==="
    python3 "$SCRIPT_DIR/patch-resource-logos.py" \
        --template "$RESOURCE" \
        --logo "$BOOT_LOGO" \
        --output "$RESOURCE_LOGO"
    mv -f "$RESOURCE_LOGO" "$RESOURCE"
else
    echo "[WARN] Boot logo not found: $BOOT_LOGO"
    echo "[WARN] Resource.img will keep the template logo"
fi

if [[ -z "$ROOT_UUID" && -f "$FACTORY_DIR/parameter.txt" ]]; then
    ROOT_UUID=$(grep -E '^uuid:rootfs=' "$FACTORY_DIR/parameter.txt" | cut -d= -f2- || true)
fi

CMDLINE="earlycon=uart8250,mmio32,0xff0d0000 console=tty0 console=${CONSOLE} loglevel=7 rootdelay=${ROOT_DELAY} systemd.color=${SYSTEMD_COLOR}"
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

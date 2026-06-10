#!/usr/bin/env bash
# End-to-end: Armbian .img -> versioned monolithic RK3308 eMMC update.img
#
# Run in WSL/Ubuntu (pack step needs loop mounts).
# Final flash file is built on Windows via AFPTool + RKImageMaker.
#
# Usage:
#   ./build-emmc-release.sh --armbian ./Armbian-*.img --version 1.0.0
#
# Options:
#   --armbian PATH     built Armbian image (required)
#   --version VER      release version string (required)
#   --factory DIR      bootloader blobs (default: factory_fresh/03_partitions)
#   --shrink           shrink rootfs before pack (recommended)
#   --skip-modules     do not extract/inject factory WiFi modules
#   --pack-only        skip windows pack (staging only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARMBIAN_IMG=""
VERSION=""
FACTORY_DIR="$SCRIPT_DIR/factory_fresh/03_partitions"
SHRINK=1
SKIP_MODULES=0
PACK_ONLY=0

usage() {
    sed -n '1,16p' "$0"
    echo ""
    echo "Example:"
    echo "  ./build-emmc-release.sh --armbian output/Armbian-*.img --version 1.0.0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --armbian) ARMBIAN_IMG="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        --factory) FACTORY_DIR="$2"; shift 2 ;;
        --shrink) SHRINK=1; shift ;;
        --no-shrink) SHRINK=0; shift ;;
        --skip-modules) SKIP_MODULES=1; shift ;;
        --pack-only) PACK_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown: $1"; usage; exit 1 ;;
    esac
done

[[ -n "$ARMBIAN_IMG" && -n "$VERSION" ]] || { usage; exit 1; }
[[ -f "$ARMBIAN_IMG" ]] || { echo "Missing: $ARMBIAN_IMG"; exit 1; }

OUT_DIR="$SCRIPT_DIR/releases/$VERSION"
PACK_INPUT="$OUT_DIR/pack_input"
OUTPUT_IMG="rk3308bs-${VERSION}-emmc.img"

echo "=== RK3308BS eMMC release $VERSION ==="
echo "Armbian: $ARMBIAN_IMG"
echo "Factory: $FACTORY_DIR"
echo "Out:     $OUT_DIR"
echo ""

if [[ "$SKIP_MODULES" != "1" ]]; then
    if [[ ! -f "$SCRIPT_DIR/bsp/modules-factory/KERNEL_VERSION" ]]; then
        echo "=== Extract WiFi modules from factory rootfs (one-time per factory dump) ==="
        bash "$SCRIPT_DIR/tools/extract-factory-modules.sh"
    fi
fi

PACK_ARGS=(
    --armbian "$ARMBIAN_IMG"
    --factory "$FACTORY_DIR"
    --out "$OUT_DIR"
    --version "$VERSION"
)
[[ "$SHRINK" == "1" ]] && PACK_ARGS+=(--shrink)
[[ "$SKIP_MODULES" != "1" ]] && PACK_ARGS+=(--modules "$SCRIPT_DIR/bsp/modules-factory")

bash "$SCRIPT_DIR/pack-armbian-for-emmc.sh" "${PACK_ARGS[@]}"

if [[ "$PACK_ONLY" == "1" ]]; then
    echo "Pack-only done. Run windows-pack-update.ps1 manually."
    exit 0
fi

if command -v powershell.exe >/dev/null 2>&1; then
    WIN_PACK="$(wslpath -w "$SCRIPT_DIR/windows-pack-update.ps1")"
    WIN_INPUT="$(wslpath -w "$PACK_INPUT")"
    echo "=== Building monolithic update.img (Windows tools) ==="
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PACK" \
        -PackInput "$WIN_INPUT" -Output "$OUTPUT_IMG"
    FINAL="$OUT_DIR/$OUTPUT_IMG"
    if [[ -f "$FINAL" ]]; then
        echo ""
        echo "Release ready: $FINAL"
        echo "Flash: RKDevTool -> Upgrade Firmware (stable USB, 5-8 min)"
        echo "Verify on board: cat /etc/rk3308bs-release"
    fi
else
    echo ""
    echo "Run on Windows to finish:"
    echo "  .\\windows-pack-update.ps1 -PackInput \"$PACK_INPUT\" -Output \"$OUTPUT_IMG\""
fi

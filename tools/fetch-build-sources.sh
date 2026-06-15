#!/usr/bin/env bash
# Fetch git source trees and verify build inputs for the eMMC pipeline.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO/config.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

ARMBIAN_BUILD="${BUILD_ARMBIAN_PATH:-${BUILD_SERVER_PATH:-$HOME/armbian-build}}"
KERNEL_SRC="${KERNEL_SRC_PATH:-$HOME/linux-v13-build}"
REL="$REPO/releases/1.0.0"
FAC_PART="$REPO/factory_fresh/03_partitions"
FAC_BOOT="$REPO/factory_fresh/04_boot_unpacked"
FETCH_KERNEL="${FETCH_KERNEL_SOURCE:-1}"
FETCH_ARMBIAN="${FETCH_ARMBIAN_SOURCE:-1}"

info() { echo ">>> $*"; }
warn() { echo "WARN: $*"; }
ok()   { echo "OK: $*"; }

bash "$SCRIPT_DIR/install-build-deps.sh"

if [[ "$FETCH_ARMBIAN" == "1" ]]; then
  if [[ ! -d "$ARMBIAN_BUILD/.git" ]]; then
    info "Cloning Armbian build framework -> $ARMBIAN_BUILD"
    git clone --depth 1 https://github.com/armbian/build "$ARMBIAN_BUILD"
  else
    ok "Armbian build tree present: $ARMBIAN_BUILD"
  fi
fi

if [[ "$FETCH_KERNEL" == "1" ]]; then
  if [[ ! -d "$KERNEL_SRC/.git" ]]; then
    info "Cloning Linux stable v6.18 -> $KERNEL_SRC"
    git clone --depth 1 --branch v6.18 \
      https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$KERNEL_SRC" \
      || git clone --depth 1 --branch linux-6.18.y \
        https://github.com/gregkh/linux.git "$KERNEL_SRC"
  else
    ok "Kernel source present: $KERNEL_SRC"
  fi
fi

# Factory partition blobs (gitignored) â€” copy from user path if provided
if [[ -n "${FACTORY_FIRMWARE_DIR:-}" && -d "$FACTORY_FIRMWARE_DIR" ]]; then
  if [[ ! -f "$FAC_PART/boot.img" ]]; then
    info "Copying factory partitions from $FACTORY_FIRMWARE_DIR"
    mkdir -p "$FAC_PART"
    cp -a "$FACTORY_FIRMWARE_DIR"/. "$FAC_PART/"
  fi
fi

if [[ -f "$FAC_PART/boot.img" && ! -f "$FAC_BOOT/resource.img" ]]; then
  info "Unpacking factory boot.img -> 04_boot_unpacked/"
  INSTALL_DEPS=0 bash "$REPO/factory_fresh/unpack-boot.sh"
elif [[ -f "$FAC_BOOT/resource.img" ]]; then
  ok "factory resource.img template present"
else
  warn "factory_fresh/03_partitions missing â€” provide FACTORY_FIRMWARE_DIR in config.env"
  warn "See factory_fresh/EXTRACTION_SUMMARY.txt"
fi

mkdir -p "$REL"

# Optional prebuilt artifact bundle (large binaries not in git)
if [[ -n "${BUILD_ARTIFACTS_URL:-}" ]]; then
  STAMP="$REL/.artifacts-fetched"
  if [[ ! -f "$STAMP" ]]; then
    info "Downloading build artifacts from BUILD_ARTIFACTS_URL"
    TMP="$(mktemp -d)"
    curl -fsSL "$BUILD_ARTIFACTS_URL" -o "$TMP/artifacts.tar.gz"
    tar -xzf "$TMP/artifacts.tar.gz" -C "$REL"
    rm -rf "$TMP"
    touch "$STAMP"
  else
    ok "Build artifacts already fetched ($STAMP)"
  fi
fi

missing=0
check_file() {
  local f="$1" hint="$2"
  if [[ -f "$f" ]]; then ok "$f"; else warn "Missing: $f â€” $hint"; missing=1; fi
}

echo ""
echo "=== Verifying eMMC build inputs (build-release-v64.sh) ==="
check_file "$REL/_Image-v22" "build with tools/build-kernel-v22-wifi.sh or set BUILD_ARTIFACTS_URL"
check_file "$REL/rootfs-v61.img" "build Armbian rootfs or extract from prior release"
check_file "$REL/_uboot-memlayout.img" "from prior boot build or BUILD_ARTIFACTS_URL"
check_file "$FAC_BOOT/resource.img" "run factory_fresh/unpack-boot.sh"
check_file "$FAC_PART/MiniLoaderAll.bin" "factory partition extract"
if [[ -f "$REL/_modules_6.18.0-dirty/kernel/drivers/leds/leds-pwm.ko" ]]; then
  ok "leds-pwm.ko module"
else
  warn "Missing leds-pwm.ko â€” run kernel module build or BUILD_ARTIFACTS_URL"
  missing=1
fi

if [[ "$missing" -eq 0 ]]; then
  echo ""
  echo "All required build inputs present. Run: bash tools/build-release-v64.sh"
else
  echo ""
  echo "Source libraries installed/cloned. Some release binaries still missing:"
  echo "  1) Set BUILD_ARTIFACTS_URL in config.env to a release tarball"
  echo "  2) Build kernel: bash tools/build-kernel-v22-wifi.sh"
  echo "  3) Copy rootfs/kernel images into releases/1.0.0/"
  echo "You can re-run: bash tools/fetch-build-sources.sh"
fi

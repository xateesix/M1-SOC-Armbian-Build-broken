#!/usr/bin/env bash
# Create GPL build-artifacts tarball for GitHub Releases (private maintainer use).
# Does not include finished .img or development history.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
REL="$REPO/releases/1.0.0"
VER="${1:-v0.64.1}"
OUT="$REL/build-artifacts-${VER}.tar.gz"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

need() { [[ -f "$1" ]] || { echo "Missing $1"; exit 1; }; }

need "$REL/_Image-v22"
need "$REL/rootfs-v61.img"
need "$REL/_uboot-memlayout.img"
need "$REL/_modules_6.18.0-dirty/kernel/drivers/leds/leds-pwm.ko"

FAC_PART="$REPO/factory_fresh/03_partitions"
FAC_BOOT="$REPO/factory_fresh/04_boot_unpacked"
need "$FAC_PART/MiniLoaderAll.bin"
need "$FAC_PART/package-file"
need "$FAC_PART/parameter.txt"
need "$FAC_PART/trust.img"
need "$FAC_PART/misc.img"
need "$FAC_PART/recovery.img"
need "$FAC_BOOT/resource.img"

mkdir -p "$STAGE/releases/1.0.0" "$STAGE/partition_templates/03_partitions" "$STAGE/partition_templates/04_boot_unpacked"

cp "$REL/_Image-v22" "$STAGE/releases/1.0.0/"
cp "$REL/rootfs-v61.img" "$STAGE/releases/1.0.0/"
cp "$REL/_uboot-memlayout.img" "$STAGE/releases/1.0.0/"
cp -a "$REL/_modules_6.18.0-dirty" "$STAGE/releases/1.0.0/"

for f in MiniLoaderAll.bin package-file parameter.txt trust.img misc.img recovery.img; do
  cp "$FAC_PART/$f" "$STAGE/partition_templates/03_partitions/"
done
cp "$FAC_BOOT/resource.img" "$STAGE/partition_templates/04_boot_unpacked/"

tar -czf "$OUT" -C "$STAGE" releases partition_templates
ls -lh "$OUT"
echo "Upload to GitHub Releases as build-artifacts-${VER}.tar.gz"
echo "Set BUILD_ARTIFACTS_URL to the release asset URL in config.env"
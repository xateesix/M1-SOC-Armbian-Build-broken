#!/usr/bin/env bash
# Extract uncompressed Image + board DTB from a finished Armbian .img
set -euo pipefail

ARMBIAN_IMG="${1:?usage: extract-armbian-boot-artifacts.sh ARMBIAN.img OUT_DIR}"
OUT_DIR="${2:?}"
DTB_NAME="${3:-rk3308bs-evb-amic-v11.dtb}"

[[ -f "$ARMBIAN_IMG" ]] || { echo "Missing: $ARMBIAN_IMG"; exit 1; }
mkdir -p "$OUT_DIR"

need() { command -v "$1" >/dev/null || { echo "Need: $1"; exit 1; }; }
need python3

WORKDIR="$(mktemp -d)"
LOOP=""
cleanup() {
    sudo umount "$WORKDIR/mnt" 2>/dev/null || true
    [[ -n "$LOOP" ]] && sudo losetup -d "$LOOP" 2>/dev/null || true
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

mkdir -p "$WORKDIR/mnt"

ROOT_DEV=""
LOOP=$(sudo losetup -f --show -P "$ARMBIAN_IMG")
sudo partprobe "$LOOP" 2>/dev/null || sleep 1
for p in 1 2; do
    if [[ -b "${LOOP}p${p}" ]]; then
        ROOT_DEV="${LOOP}p${p}"
        break
    fi
done
if [[ -z "$ROOT_DEV" ]] && command -v lsblk >/dev/null; then
    ROOT_DEV=$(lsblk -ln -o NAME,FSTYPE "$LOOP" 2>/dev/null | awk '$2 ~ /ext4|Linux/ {print "/dev/"$1; exit}')
fi
if [[ -z "$ROOT_DEV" || ! -b "$ROOT_DEV" ]]; then
    PART_START=$(fdisk -l "$ARMBIAN_IMG" 2>/dev/null | awk '/Linux root|Linux filesystem/ {print $2; exit}')
    if [[ -n "$PART_START" && "$PART_START" -gt 0 ]]; then
        sudo losetup -d "$LOOP" 2>/dev/null || true
        LOOP=""
        LOOP=$(sudo losetup -f --show -o "$((PART_START * 512))" "$ARMBIAN_IMG")
        ROOT_DEV="$LOOP"
    fi
fi
[[ -n "$ROOT_DEV" && -b "$ROOT_DEV" ]] || { echo "No root partition in $ARMBIAN_IMG"; exit 1; }

sudo mount -o ro "$ROOT_DEV" "$WORKDIR/mnt"

IMAGE_SRC=""
for cand in "$WORKDIR/mnt/boot/Image" "$WORKDIR/mnt/boot/vmlinuz-"*; do
    [[ -f "$cand" ]] && { IMAGE_SRC="$cand"; break; }
done
[[ -n "$IMAGE_SRC" ]] || { echo "No /boot/Image in Armbian image"; exit 1; }

DTB_SRC="$(find "$WORKDIR/mnt/boot/dtb-"* -path "*/rockchip/$DTB_NAME" 2>/dev/null | head -1 || true)"
if [[ -z "$DTB_SRC" ]]; then
    REPO_DTB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dts/$DTB_NAME"
    if [[ -f "$REPO_DTB" ]]; then
        echo "Using repo DTB fallback: $REPO_DTB"
        cp "$REPO_DTB" "$OUT_DIR/$DTB_NAME"
        cp "$IMAGE_SRC" "$OUT_DIR/Image"
        KVER="$(find "$WORKDIR/mnt/boot/dtb-"* -maxdepth 0 -type d 2>/dev/null | head -1 | xargs -r basename | sed 's/dtb-//')"
        [[ -z "$KVER" ]] && KVER="6.18.35"
        echo "IMAGE=$OUT_DIR/Image"
        echo "DTB=$OUT_DIR/$DTB_NAME"
        echo "KERNEL_VERSION=$KVER"
        echo "$KVER" >"$OUT_DIR/KERNEL_VERSION"
        exit 0
    fi
    echo "Missing DTB rockchip/$DTB_NAME in Armbian image (and no $REPO_DTB)"
    exit 1
fi

cp "$IMAGE_SRC" "$OUT_DIR/Image"
cp "$DTB_SRC" "$OUT_DIR/$DTB_NAME"

KVER="$(basename "$(dirname "$(dirname "$DTB_SRC")")" | sed 's/dtb-//')"
echo "IMAGE=$OUT_DIR/Image"
echo "DTB=$OUT_DIR/$DTB_NAME"
echo "KERNEL_VERSION=$KVER"
echo "$KVER" >"$OUT_DIR/KERNEL_VERSION"

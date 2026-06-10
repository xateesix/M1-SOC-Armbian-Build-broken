#!/usr/bin/env bash
# Quick checks to debug why the firmware doesn't boot

ARMBIAN_PATH="${ARMBIAN_PATH:-$HOME/armbian-build}"
IMAGE_DIR="$ARMBIAN_PATH/output/images"

echo "=== 1. Check if DTB was compiled ==="
find "$ARMBIAN_PATH/.cache" -name "rk3308bs-evb-amic-v11.dtb" 2>/dev/null | head -5
echo ""

echo "=== 2. Check if DTB is in the output image ==="
# Find the latest .img file
LATEST_IMG=$(ls -t "$IMAGE_DIR"/*.img 2>/dev/null | head -1)
if [ -n "$LATEST_IMG" ]; then
    echo "Latest image: $LATEST_IMG"
    echo ""
    echo "=== 3. Mount and check boot partition ==="
    # Extract boot partition (usually first partition, starts at 32k or 16M)
    # For GPT: usually partition 1 is /boot (FAT32)
    LOOP_DEV=$(sudo losetup -f)
    sudo losetup "$LOOP_DEV" "$LATEST_IMG"
    sudo partprobe "$LOOP_DEV"
    
    echo "Partitions in image:"
    sudo fdisk -l "$LOOP_DEV"
    echo ""
    
    # Mount first partition (assume it's /boot)
    BOOT_MNT="/tmp/armbian-boot-check"
    mkdir -p "$BOOT_MNT"
    sudo mount "${LOOP_DEV}p1" "$BOOT_MNT"
    
    echo "=== 4. Boot partition contents ==="
    ls -lah "$BOOT_MNT/"
    echo ""
    
    echo "=== 5. Check boot.cmd / extlinux.conf / armbianEnv.txt ==="
    for f in "$BOOT_MNT"/boot.cmd "$BOOT_MNT"/boot.scr "$BOOT_MNT"/extlinux/extlinux.conf "$BOOT_MNT"/armbianEnv.txt; do
        if [ -f "$f" ]; then
            echo ">>> File: $f"
            cat "$f"
            echo ""
        fi
    done
    
    echo "=== 6. Check if DTB is present ==="
    find "$BOOT_MNT" -name "*.dtb" -o -name "*rk3308*"
    echo ""
    
    # Cleanup
    sudo umount "$BOOT_MNT"
    sudo losetup -d "$LOOP_DEV"
else
    echo "No .img file found in $IMAGE_DIR"
fi

echo ""
echo "=== 7. Check kernel DTS for label correctness ==="
KERNEL_SRC="$ARMBIAN_PATH/.cache/sources/linux-rockchip64-current"
if [ -d "$KERNEL_SRC" ]; then
    echo "Checking rk3308.dtsi for labels..."
    grep -n "uart3\|i2s2\|rgb_out\|pwm8\|pwm9" "$KERNEL_SRC/arch/arm64/boot/dts/rockchip/rk3308.dtsi" | head -20
else
    echo "Kernel source not yet cached at: $KERNEL_SRC"
fi

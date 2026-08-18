#!/bin/bash
# Copied to userpatches/customize-image.sh during build-enhanced.sh setup.
# Runs inside Armbian compile after rootfs is populated.

run_chroot_hook() {
    local chroot_dir="$1"
    local hook_path="$2"

    [[ -d "$chroot_dir" ]] || return 0
    [[ -f "$hook_path" ]] || return 0

    local hook_name
    hook_name="$(basename "$hook_path")"

    mkdir -p "$chroot_dir/tmp"
    cp "$hook_path" "/tmp/$hook_name"
    chmod +x "/tmp/$hook_name"
    cp "/tmp/$hook_name" "$chroot_dir/tmp/$hook_name"
    chmod +x "$chroot_dir/tmp/$hook_name"
    chroot "$chroot_dir" /bin/bash "/tmp/$hook_name"
    rm -f "$chroot_dir/tmp/$hook_name" "/tmp/$hook_name"
}

function rk3308bs_customize_rootfs() {
    local chroot_dir="${1:-$SDCARD}"

    [[ -d "$chroot_dir" ]] || return 0

    run_chroot_hook "$chroot_dir" "${EXTER}/config/20-rk3308bs-hardware.sh"
    run_chroot_hook "$chroot_dir" "${EXTER}/config/25-rk3308bs-emmc-layout.sh"
    run_chroot_hook "$chroot_dir" "${EXTER}/config/30-rk3308bs-preconfigure.sh"
    run_chroot_hook "$chroot_dir" "${EXTER}/config/35-rk3308bs-companion-stack.sh"
}

function customize_image() {
    rk3308bs_customize_rootfs "$SDCARD"
}

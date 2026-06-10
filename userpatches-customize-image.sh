#!/bin/bash
# Copied to userpatches/customize-image.sh during build-enhanced.sh setup.
# Runs inside Armbian compile after rootfs is populated.
function rk3308bs_customize_rootfs() {
    local chroot_dir="${1:-$SDCARD}"

    [[ -d "$chroot_dir" ]] || return 0

    if [[ -f "${EXTER}/config/20-rk3308bs-hardware.sh" ]]; then
        cp "${EXTER}/config/20-rk3308bs-hardware.sh" /tmp/rk3308bs-hw.sh
        chmod +x /tmp/rk3308bs-hw.sh
        cp /tmp/rk3308bs-hw.sh "${chroot_dir}/tmp/rk3308bs-hw.sh"
        chroot "${chroot_dir}" /bin/bash /tmp/rk3308bs-hw.sh
        rm -f "${chroot_dir}/tmp/rk3308bs-hw.sh" /tmp/rk3308bs-hw.sh
    fi
}

function customize_image() {
    rk3308bs_customize_rootfs "$SDCARD"
}

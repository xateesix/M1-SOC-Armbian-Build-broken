#!/usr/bin/env bash
# =============================================================================
# Armbian build setup for Rockchip RK3308B-S EVB Analog MIC V11
#
# Prerequisites on the Ubuntu build machine:
#   git, docker (optional but recommended), basic build-essential tools.
#   Armbian build system must already be cloned at $ARMBIAN_PATH.
#
# Usage:
#   ./build.sh                        # full image build
#   ./build.sh kernel                 # rebuild kernel/DTB only (fast)
#   ./build.sh KERNEL_CONFIGURE=yes   # open menuconfig before build
#   ARMBIAN_PATH=/some/other/path ./build.sh
# =============================================================================
set -euo pipefail

ARMBIAN_PATH="${ARMBIAN_PATH:-$HOME/armbian-build}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colours ───────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Step 0: sanity checks ─────────────────────────────────────────────────
if [ ! -f "$ARMBIAN_PATH/compile.sh" ]; then
    warn "Armbian build system not found at: $ARMBIAN_PATH"
    echo ""
    echo "Clone it first:"
    echo "  git clone --depth=1 https://github.com/armbian/build $ARMBIAN_PATH"
    echo ""
    echo "Then re-run this script."
    exit 1
fi

info "Armbian build system found at: $ARMBIAN_PATH"

# ── Step 1: install board configuration ───────────────────────────────────
BOARD_CONF_SRC="$SCRIPT_DIR/rk3308bs-evb.conf"
BOARD_CONF_DST="$ARMBIAN_PATH/config/boards/rk3308bs-evb.conf"

if [ ! -f "$BOARD_CONF_SRC" ]; then
    error "Board config not found: $BOARD_CONF_SRC"
fi

info "Installing board config  ->  $BOARD_CONF_DST"
cp "$BOARD_CONF_SRC" "$BOARD_CONF_DST"
# Strip Windows CRLF line endings (\r\n  ->  \n)
sed -i 's/\r$//' "$BOARD_CONF_DST"

# ── Step 2: install kernel DTS patch ──────────────────────────────────────
PATCH_SRC="$SCRIPT_DIR/patches/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch"
PATCH_DST_DIR="$ARMBIAN_PATH/userpatches/kernel/rockchip64-current"

if [ ! -f "$PATCH_SRC" ]; then
    error "Kernel patch not found: $PATCH_SRC"
fi

info "Installing kernel patch  ->  $PATCH_DST_DIR/"
mkdir -p "$PATCH_DST_DIR"
cp "$PATCH_SRC" "$PATCH_DST_DIR/"
sed -i 's/\r$//' "$PATCH_DST_DIR/$(basename "$PATCH_SRC")"

# ── Step 3: verify the DTS source is present (informational) ──────────────
DTS_SRC="$SCRIPT_DIR/dts/rk3308bs-evb-amic-v11.dts"
if [ -f "$DTS_SRC" ]; then
    info "DTS source available at: $DTS_SRC"
    info "(The patch above will inject it into the kernel tree automatically)"
fi

# ── Step 4: check U-Boot defconfig availability ───────────────────────────
#
# The board config requests "evb-rk3308_defconfig".
# Armbian's Rockchip64 family will attempt to build U-Boot with this config.
# If the build fails with "unknown board", fall back to Rock Pi S config:
#
#   sed -i 's/evb-rk3308_defconfig/rock-pi-s-rk3308_defconfig/' \
#       "$BOARD_CONF_DST"
#
# Both boards share the same RK3308 SoC and similar DDR3 layout.
warn "U-Boot config: using 'evb-rk3308_defconfig'."
warn "If U-Boot compilation fails, edit $BOARD_CONF_DST"
warn "and change BOOTCONFIG to 'rock-pi-s-rk3308_defconfig'."
echo ""

# ── Step 5: DTS label verification reminder ───────────────────────────────
cat <<'EOF'
┌─────────────────────────────────────────────────────────────────────────┐
|  BEFORE BUILDING  -  verify these DTS labels match your kernel version:   |
|                                                                         |
|  1. I2S for ACODEC:                                                     |
|       grep -n "ff320000" $ARMBIAN_PATH/                                 |
|           <cache>/sources/linux-rockchip64-current/                     |
|           arch/arm64/boot/dts/rockchip/rk3308.dtsi                      |
|     Change &i2s2 in the DTS if the label differs.                       |
|                                                                         |
|  2. RGB display bridge endpoint:                                        |
|       grep -n "rgb_out\|rgb@" <same rk3308.dtsi path>                  |
|     Adjust &rgb_out in the DTS if the endpoint label differs.           |
|                                                                         |
|  3. PWM labels (vdd_core = &pwm8, backlight = &pwm9):                  |
|       grep -n "ff18000" <same rk3308.dtsi path>                         |
|     Confirm pwm8 = ff180000, pwm9 = ff180010.                           |
|                                                                         |
|  4. Touch screen size:                                                  |
|     The GT911 OEM firmware was configured for 800x480.                  |
|     If touch coordinates are wrong, reflash GT911 config or override    |
|     the touchscreen-size-x/y values in the DTS.                         |
--───────────────────────────────────────────────────────────────────────┘

EOF

# ── Step 6: run the Armbian build ─────────────────────────────────────────
info "Starting Armbian build for rk3308bs-evb (branch: current, release: jammy)"
info "First run downloads toolchains and takes 30 - 90 minutes."
echo ""

cd "$ARMBIAN_PATH"

# PREFER_DOCKER=no   ->  skip the Docker-unavailable countdown/prompt entirely
#                     and go straight to sudo native build.
# Pass any extra arguments from the command line (e.g. KERNEL_ONLY=yes)
./compile.sh \
    BOARD=rk3308bs-evb \
    BRANCH=current \
    RELEASE=jammy \
    EXPERT=yes \
    PREFER_DOCKER=no \
    BUILD_MINIMAL=no \
    KERNEL_CONFIGURE=no \
    COMPRESS_OUTPUTIMAGE=yes \
    "$@"

echo ""
info "Build complete. Output image is in: $ARMBIAN_PATH/output/images/"
echo ""
echo "Flash to microSD with:"
echo "  dd if=<image>.img of=/dev/sdX bs=4M status=progress conv=fsync"
echo ""
echo "Or use the Armbian output/images/*.img.xz with balenaEtcher."

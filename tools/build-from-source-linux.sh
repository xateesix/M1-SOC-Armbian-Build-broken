#!/usr/bin/env bash
# Build a firmware package from source using Linux-only tooling.
#
# This script intentionally avoids the legacy rootfs-v61 patch chain.
# Flow:
#   1) Prepare Armbian userpatches from this repo
#   2) Compile fresh Armbian image from source
#   3) Stage pack_input from the compiled Armbian image
#   4) Pack monolithic RKFW image with Linux afptool + rkImageMaker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
ARMBIAN_BUILD_PATH_DEFAULT="/home/xateesix/scratch/Projects/rk3308bs-workspace/M1-Pro-SOC_armbian-build/armbian-project"
ARMBIAN_BUILD_PATH="${ARMBIAN_BUILD_PATH:-$ARMBIAN_BUILD_PATH_DEFAULT}"
RELEASE_TAG="${RELEASE_TAG:-v64-from-source-linux}"
DIST_RELEASE="${DIST_RELEASE:-bookworm}"
KERNEL_BRANCH="${KERNEL_BRANCH:-current}"
KERNEL_BTF="${KERNEL_BTF:-no}"
FACTORY_DIR="${FACTORY_DIR:-$PROJECT_ROOT/factory_fresh/03_partitions}"
RKTOOLS_BIN="${RKTOOLS_BIN:-$WORKSPACE_ROOT/tools/vendor/emmc-pack/bin}"
SKIP_COMPILE="${SKIP_COMPILE:-0}"
OVERWRITE_RELEASE="${OVERWRITE_RELEASE:-0}"
RK3308BS_TSADC="${RK3308BS_TSADC:-0}"
GOODIX_FACTORY_DEFAULTS="${GOODIX_FACTORY_DEFAULTS:-0}"
DISABLE_THERMAL_CRITICAL="${DISABLE_THERMAL_CRITICAL:-0}"
DISABLE_TSADC="${DISABLE_TSADC:-0}"
PRECONFIGURE_CREDENTIALS="${PRECONFIGURE_CREDENTIALS:-0}"

CONFIG_FILE=""
for candidate in \
    "$ARMBIAN_BUILD_PATH/config.env" \
    "$PROJECT_ROOT/config.env" \
    "$WORKSPACE_ROOT/M1-Pro-SOC_armbian-build/armbian-project/config.env"; do
    if [[ -f "$candidate" ]]; then
        CONFIG_FILE="$candidate"
        break
    fi
done
if [[ -n "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

PATCH_DTS="$PROJECT_ROOT/patches/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch"
PATCH_THERMAL="$PROJECT_ROOT/patches/0002-thermal-rockchip-rk3308bs-tsadc.patch"
BOARD_CONF="$PROJECT_ROOT/rk3308bs-evb.conf"
CUSTOMIZE_IMAGE="$PROJECT_ROOT/userpatches-customize-image.sh"
HW_CHROOT="$PROJECT_ROOT/userpatches-chroot/20-rk3308bs-hardware.sh"
EMMC_LAYOUT_CHROOT="$PROJECT_ROOT/userpatches-chroot/25-rk3308bs-emmc-layout.sh"
PRECONFIG_CHROOT="$PROJECT_ROOT/userpatches-chroot/30-rk3308bs-preconfigure.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --armbian-build-path PATH   Path to armbian build fork (default: $ARMBIAN_BUILD_PATH_DEFAULT)
  --release-tag TAG           Output release directory tag (default: v64-from-source-linux)
  --dist-release NAME         Armbian distro release (default: bookworm)
  --kernel-branch NAME        Armbian kernel branch (default: current)
  --factory-dir PATH          Factory partition bundle dir (default: factory_fresh/03_partitions)
  --rktools-bin PATH          Directory containing afptool + rkImageMaker (default: /home/xateesix/emmc-pack/bin)
  --skip-compile              Skip compile.sh and reuse latest existing Armbian image
  --preconfigure-credentials  Bake user/password/WiFi via config/30 hook (default: disabled)
  --allow-overwrite           Allow reusing an existing release tag directory
  -h, --help                  Show this help

Environment alternatives:
    ARMBIAN_BUILD_PATH, RELEASE_TAG, DIST_RELEASE, KERNEL_BRANCH, FACTORY_DIR, RKTOOLS_BIN,
    SKIP_COMPILE, OVERWRITE_RELEASE, PRECONFIGURE_CREDENTIALS
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --armbian-build-path) ARMBIAN_BUILD_PATH="$2"; shift 2 ;;
        --release-tag) RELEASE_TAG="$2"; shift 2 ;;
        --dist-release) DIST_RELEASE="$2"; shift 2 ;;
        --kernel-branch) KERNEL_BRANCH="$2"; shift 2 ;;
        --factory-dir) FACTORY_DIR="$2"; shift 2 ;;
        --rktools-bin) RKTOOLS_BIN="$2"; shift 2 ;;
        --skip-compile) SKIP_COMPILE=1; shift ;;
        --preconfigure-credentials) PRECONFIGURE_CREDENTIALS=1; shift ;;
        --allow-overwrite) OVERWRITE_RELEASE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

need_file() {
    local file="$1"
    [[ -f "$file" ]] || { echo "[ERROR] Missing file: $file"; exit 1; }
}

need_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || { echo "[ERROR] Missing directory: $dir"; exit 1; }
}

need_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || { echo "[ERROR] Missing command: $cmd"; exit 1; }
}

need_nonempty_file() {
    local file="$1"
    [[ -f "$file" ]] || { echo "[ERROR] Missing file: $file"; exit 1; }
    [[ -s "$file" ]] || { echo "[ERROR] File is empty: $file"; exit 1; }
}

resolve_factory_dir() {
    local current="$1"
    if [[ -d "$current" ]]; then
        echo "$current"
        return 0
    fi

    local candidate
    candidate="$WORKSPACE_ROOT/M1-Pro-SOC_armbian-build/config/Armbian-M1-Pro-X1_SOC/Armbian-M1-SOC/factory_fresh/03_partitions"
    if [[ -d "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi

    echo "$current"
}

ensure_inside_workspace() {
    local input_path="$1"
    local label="$2"
    local resolved

    resolved="$(realpath -m "$input_path")"
    if [[ "$resolved" != "$WORKSPACE_ROOT"* ]]; then
        echo "[ERROR] $label must be inside workspace: $WORKSPACE_ROOT"
        echo "        Current: $resolved"
        exit 1
    fi
}

find_latest_armbian_image() {
    local out_dir="$1"
    local latest

    latest="$(ls -1t "$out_dir"/Armbian-*Rk3308bs-evb*.img 2>/dev/null | head -n1 || true)"
    if [[ -n "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    latest="$(ls -1t "$out_dir"/Armbian-*Rk3308bs-evb*.img.xz 2>/dev/null | head -n1 || true)"
    if [[ -n "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    return 1
}

install_userpatches() {
    local build_path="$1"
    local yaml_ssid yaml_password

    mkdir -p "$build_path/config/boards"
    mkdir -p "$build_path/userpatches/kernel/rockchip64-current"
    mkdir -p "$build_path/userpatches/kernel/archive/rockchip64-6.18"
    mkdir -p "$build_path/userpatches/overlay-user"

    cp "$BOARD_CONF" "$build_path/config/boards/rk3308bs-evb.conf"
    sed -i 's/\r$//' "$build_path/config/boards/rk3308bs-evb.conf"

    cp "$PATCH_DTS" "$build_path/userpatches/kernel/rockchip64-current/0001-add-rk3308bs-evb.patch"
    cp "$PATCH_DTS" "$build_path/userpatches/kernel/archive/rockchip64-6.18/0001-add-rk3308bs-evb.patch"
    sed -i 's/\r$//' "$build_path/userpatches/kernel/rockchip64-current/0001-add-rk3308bs-evb.patch"
    sed -i 's/\r$//' "$build_path/userpatches/kernel/archive/rockchip64-6.18/0001-add-rk3308bs-evb.patch"

    if [[ -f "$PATCH_THERMAL" ]]; then
        cp "$PATCH_THERMAL" "$build_path/userpatches/kernel/rockchip64-current/0002-rk3308bs-tsadc.patch"
        cp "$PATCH_THERMAL" "$build_path/userpatches/kernel/archive/rockchip64-6.18/0002-rk3308bs-tsadc.patch"
        sed -i 's/\r$//' "$build_path/userpatches/kernel/rockchip64-current/0002-rk3308bs-tsadc.patch"
        sed -i 's/\r$//' "$build_path/userpatches/kernel/archive/rockchip64-6.18/0002-rk3308bs-tsadc.patch"
    fi

    if [[ -n "${WIFI_SSID:-}" && -n "${WIFI_PASSWORD:-}" ]]; then
        yaml_ssid="${WIFI_SSID//\\/\\\\}"
        yaml_ssid="${yaml_ssid//\"/\\\"}"
        yaml_password="${WIFI_PASSWORD//\\/\\\\}"
        yaml_password="${yaml_password//\"/\\\"}"
        mkdir -p "$build_path/userpatches/overlay-user/etc/netplan"
        cat > "$build_path/userpatches/overlay-user/etc/netplan/01-rk3308bs-wlan0.yaml" <<EOF
network:
  version: 2
  renderer: networkd
  wifis:
    wlan0:
      optional: true
      dhcp4: true
      access-points:
        "$yaml_ssid":
          password: "$yaml_password"
EOF
        chmod 600 "$build_path/userpatches/overlay-user/etc/netplan/01-rk3308bs-wlan0.yaml"
    fi

    if [[ -d "$PROJECT_ROOT/overlay-user" ]]; then
        cp -a "$PROJECT_ROOT/overlay-user/." "$build_path/userpatches/overlay-user/"
    fi

    cat > "$build_path/userpatches/firstboot.conf" <<EOF
PRESET_ROOT_PASSWORD=$ROOT_PASSWORD
PRESET_USER_NAME=${USER_NAME:-m1prox1}
PRESET_USER_PASSWORD=${USER_PASSWORD:-$ROOT_PASSWORD}
PRESET_DEFAULT_REALNAME=${USER_REALNAME:-${USER_NAME:-m1prox1}}
PRESET_LOCALE=${LOCALE:-en_US.UTF-8}
PRESET_TIMEZONE=${TIMEZONE:-America/Los_Angeles}
PRESET_NET_CHANGE_DEFAULTS=1
PRESET_NET_ETHERNET_ENABLED=0
PRESET_NET_WIFI_ENABLED=1
PRESET_NET_WIFI_SSID=${WIFI_SSID:-}
PRESET_NET_WIFI_KEY=${WIFI_PASSWORD:-}
PRESET_NET_WIFI_COUNTRYCODE=${WIFI_COUNTRY:-US}
PRESET_CONNECT_WIRELESS=0
EOF

    if [[ -f "$CUSTOMIZE_IMAGE" ]]; then
        cp "$CUSTOMIZE_IMAGE" "$build_path/userpatches/customize-image.sh"
        chmod +x "$build_path/userpatches/customize-image.sh"
    fi

    COMPANION_CHROOT="$PROJECT_ROOT/userpatches-chroot/35-rk3308bs-companion-stack.sh"

    for hook in "$HW_CHROOT" "$EMMC_LAYOUT_CHROOT" "$COMPANION_CHROOT"; do
        if [[ -f "$hook" ]]; then
            cp "$hook" "$build_path/config/$(basename "$hook")"
            chmod +x "$build_path/config/$(basename "$hook")"
        fi
    done

    if [[ "$PRECONFIGURE_CREDENTIALS" == "1" ]]; then
        if [[ -f "$PRECONFIG_CHROOT" ]]; then
            cp "$PRECONFIG_CHROOT" "$build_path/config/$(basename "$PRECONFIG_CHROOT")"
            chmod +x "$build_path/config/$(basename "$PRECONFIG_CHROOT")"
        fi
    else
        rm -f "$build_path/config/$(basename "$PRECONFIG_CHROOT")"
    fi

    cat > "$build_path/userpatches/config.conf" <<EOF
BOARD=rk3308bs-evb
BRANCH=$KERNEL_BRANCH
RELEASE=$DIST_RELEASE
BUILD_MINIMAL=yes
EXPERT=yes
PREFER_DOCKER=no
KERNEL_CONFIGURE=no
NO_HOST_RELEASE_CHECK=yes
EOF
    ln -sf config.conf "$build_path/userpatches/config-default.conf"
}

apply_active_kernel_patch() {
    local build_path="$1"
    local kernel_dir=""
    local kernel_file=""

    if [[ ! -f "$PATCH_THERMAL" ]]; then
        return 0
    fi

    kernel_dir="$(find "$build_path/cache/sources/linux-kernel-worktree" -mindepth 1 -maxdepth 1 -type d -name '*rockchip64*' 2>/dev/null | head -n 1 || true)"
    if [[ -z "$kernel_dir" ]]; then
        echo "[WARN] No kernel worktree detected under $build_path/cache/sources/linux-kernel-worktree; skipping active-tree patch apply."
        return 0
    fi

    kernel_file="$kernel_dir/drivers/thermal/rockchip_thermal.c"
    if [[ ! -f "$kernel_file" ]]; then
        echo "[WARN] Active kernel worktree not found at $kernel_dir; skipping active-tree patch apply."
        return 0
    fi

    if grep -q 'rockchip,rk3308bs-tsadc' "$kernel_file"; then
        echo "[OK] Active kernel worktree already contains the RK3308BS TSADC patch: $kernel_dir"
        return 0
    fi

    if ! git -C "$kernel_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "[WARN] Active kernel worktree is not a git checkout; skipping active-tree patch apply."
        return 0
    fi

    echo "[1/2] Applying RK3308BS TSADC patch to active kernel worktree: $kernel_dir"
    git -C "$kernel_dir" apply --check "$PATCH_THERMAL"
    git -C "$kernel_dir" apply "$PATCH_THERMAL"
    echo "[OK] Active kernel worktree now includes the RK3308BS TSADC patch."
}

echo "=== Linux-only from-source build ==="
echo "Workspace root:     $WORKSPACE_ROOT"
echo "Project root:       $PROJECT_ROOT"
echo "Armbian build path: $ARMBIAN_BUILD_PATH"
echo "Release tag:        $RELEASE_TAG"
echo "Distro release:     $DIST_RELEASE"
echo "Kernel branch:      $KERNEL_BRANCH"
echo "Kernel BTF:         $KERNEL_BTF"
echo "RK3308BS_TSADC:     $RK3308BS_TSADC"
echo "GOODIX_DEFAULTS:    $GOODIX_FACTORY_DEFAULTS"
echo "THERMAL_CRIT_PATCH: $DISABLE_THERMAL_CRITICAL"
echo "DISABLE_TSADC:      $DISABLE_TSADC"
echo "PRECONFIG_CREDS:    $PRECONFIGURE_CREDENTIALS (default: standard Armbian first-boot flow)"
echo "Factory dir:        $FACTORY_DIR"
echo "RKTOOLS_BIN:        $RKTOOLS_BIN"

FACTORY_DIR="$(resolve_factory_dir "$FACTORY_DIR")"
echo "Resolved factory:   $FACTORY_DIR"

need_dir "$PROJECT_ROOT"
need_dir "$ARMBIAN_BUILD_PATH"
need_file "$ARMBIAN_BUILD_PATH/compile.sh"
need_dir "$FACTORY_DIR"
need_file "$FACTORY_DIR/package-file"
need_file "$FACTORY_DIR/MiniLoaderAll.bin"
need_file "$FACTORY_DIR/parameter.txt"
need_file "$FACTORY_DIR/uboot.img"
need_file "$FACTORY_DIR/trust.img"
need_file "$FACTORY_DIR/misc.img"
need_file "$FACTORY_DIR/recovery.img"

need_file "$BOARD_CONF"
need_file "$PATCH_DTS"
need_file "$CUSTOMIZE_IMAGE"
need_cmd bash
need_cmd git
need_cmd python3
need_cmd sudo
need_cmd xz
need_cmd realpath

ensure_inside_workspace "$PROJECT_ROOT" "PROJECT_ROOT"
ensure_inside_workspace "$ARMBIAN_BUILD_PATH" "ARMBIAN_BUILD_PATH"
ensure_inside_workspace "$FACTORY_DIR" "FACTORY_DIR"
ensure_inside_workspace "$RKTOOLS_BIN" "RKTOOLS_BIN"

echo "[1/5] Installing userpatches into Armbian fork"
install_userpatches "$ARMBIAN_BUILD_PATH"

if [[ -f "$PATCH_THERMAL" ]]; then
    apply_active_kernel_patch "$ARMBIAN_BUILD_PATH"
fi

if [[ "$SKIP_COMPILE" != "1" ]]; then
    echo "[2/5] Compiling Armbian image from source"
    (
        cd "$ARMBIAN_BUILD_PATH"
        ./compile.sh default \
            BOARD=rk3308bs-evb \
            BRANCH="$KERNEL_BRANCH" \
            RELEASE="$DIST_RELEASE" \
            BUILD_MINIMAL=yes \
            EXPERT=yes \
            PREFER_DOCKER=no \
            KERNEL_CONFIGURE=no \
            KERNEL_BTF="$KERNEL_BTF" \
            NO_HOST_RELEASE_CHECK=yes \
            CI=true
    )
else
    echo "[2/5] Skipping compile step (--skip-compile)"
fi

OUT_IMAGES_DIR="$ARMBIAN_BUILD_PATH/output/images"
need_dir "$OUT_IMAGES_DIR"

echo "[3/5] Selecting latest compiled Armbian image"
ARMBIAN_ARTIFACT="$(find_latest_armbian_image "$OUT_IMAGES_DIR" || true)"
if [[ -z "$ARMBIAN_ARTIFACT" ]]; then
    echo "[ERROR] Could not find Armbian image in $OUT_IMAGES_DIR"
    exit 1
fi
echo "Using artifact: $ARMBIAN_ARTIFACT"

RELEASE_DIR="$PROJECT_ROOT/releases/$RELEASE_TAG"
FINAL_IMG_CANDIDATE="$RELEASE_DIR/rk3308bs-1.0.0-${RELEASE_TAG}-emmc.img"
if [[ -d "$RELEASE_DIR" && "$OVERWRITE_RELEASE" != "1" ]]; then
    if compgen -G "$RELEASE_DIR/*.img" >/dev/null || [[ -f "$FINAL_IMG_CANDIDATE" ]]; then
        echo "[ERROR] Release tag already exists and contains image artifacts: $RELEASE_DIR"
        echo "        Pick a new --release-tag (recommended) or pass --allow-overwrite explicitly."
        exit 1
    fi
fi
mkdir -p "$RELEASE_DIR"

ARMBIAN_IMG_PATH="$ARMBIAN_ARTIFACT"
if [[ "$ARMBIAN_ARTIFACT" == *.img.xz ]]; then
    ARMBIAN_IMG_PATH="$RELEASE_DIR/_armbian-source.img"
    echo "Decompressing $ARMBIAN_ARTIFACT -> $ARMBIAN_IMG_PATH"
    xz -dkc "$ARMBIAN_ARTIFACT" > "$ARMBIAN_IMG_PATH"
fi

echo "[4/5] Staging pack_input from compiled Armbian image"
(
    cd "$PROJECT_ROOT"
    RK3308BS_TSADC="$RK3308BS_TSADC" GOODIX_FACTORY_DEFAULTS="$GOODIX_FACTORY_DEFAULTS" DISABLE_THERMAL_CRITICAL="$DISABLE_THERMAL_CRITICAL" DISABLE_TSADC="$DISABLE_TSADC" bash ./build-emmc-release.sh \
        --armbian "$ARMBIAN_IMG_PATH" \
        --version "$RELEASE_TAG" \
        --factory "$FACTORY_DIR" \
        --pack-only
)

echo "[5/5] Linux-only monolithic packaging"
(
    cd "$PROJECT_ROOT"
    RKTOOLS_BIN="$RKTOOLS_BIN" bash ./tools/pack-firmware-linux.sh "$RELEASE_TAG" "$PROJECT_ROOT"
)

FINAL_IMG="$PROJECT_ROOT/releases/$RELEASE_TAG/rk3308bs-1.0.0-${RELEASE_TAG}-emmc.img"
need_file "$FINAL_IMG"

echo ""
echo "[SUCCESS] Linux-only from-source firmware built:"
ls -lh "$FINAL_IMG"
sha256sum "$FINAL_IMG"
echo ""
echo "Flash command:"
echo "  sudo upgrade_tool UF $FINAL_IMG"

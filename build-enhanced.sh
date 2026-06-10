#!/bin/bash
# =============================================================================
# Enhanced Armbian Build for RK3308BS EVB with WiFi & Root Password Config
#
# This script:
#   1. Manages a persistent ~/armbian-build on your Ubuntu server (or local)
#   2. Pre-configures WiFi credentials (SSID + password)
#   3. Sets root password automatically
#   4. Supports GitHub sync for collaborative development
#
# Configuration:
#   Edit config.env before running
#
# Usage:
#   ./build.sh                 # Full firmware build
#   ./build.sh kernel          # Kernel/DTB only
#   BUILD_SERVER=local ./build.sh  # Build locally (if Armbian already installed)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
PATCH_FILE="$SCRIPT_DIR/patches/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch"
DTS_FILE="$SCRIPT_DIR/dts/rk3308bs-evb-amic-v11.dts"

# ── Colors ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step()  { echo -e "${BLUE}>>> $*${NC}"; }

# ── Load Configuration ────────────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    error "Missing config.env - run setup first! See README"
fi

source "$CONFIG_FILE"

# remote = SSH to BUILD_SERVER_HOST; local = WSL/native armbian-build tree
BUILD_TYPE="${BUILD_SERVER:-remote}"

info "═════════════════════════════════════════════"
info "RK3308BS EVB Armbian Build"
info "═════════════════════════════════════════════"
info "Build Type: $BUILD_TYPE"
info "WiFi SSID: $WIFI_SSID"
info "Root Password: [SET]"
if [ -n "$GITHUB_REPO" ]; then
    info "GitHub Repo: $GITHUB_REPO"
fi
info ""

# ── Verify local files ────────────────────────────────────────────────────
for f in \
    "$SCRIPT_DIR/rk3308bs-evb.conf" \
    "$PATCH_FILE" \
    "$DTS_FILE"; do
    if [ ! -f "$f" ]; then
        error "Missing: $(basename $f)"
    fi
done

_install_userpatches() {
    local BUILD_PATH="$1"

    mkdir -p "$BUILD_PATH/config/boards" "$BUILD_PATH/userpatches/overlay-user"
    cp "$SCRIPT_DIR/rk3308bs-evb.conf" "$BUILD_PATH/config/boards/rk3308bs-evb.conf"
    sed -i 's/\r$//' "$BUILD_PATH/config/boards/rk3308bs-evb.conf"

    mkdir -p "$BUILD_PATH/userpatches/kernel/rockchip64-current"
    cp "$PATCH_FILE" "$BUILD_PATH/userpatches/kernel/rockchip64-current/0001-add-rk3308bs-evb.patch"
    sed -i 's/\r$//' "$BUILD_PATH/userpatches/kernel/rockchip64-current/"*.patch

    mkdir -p "$BUILD_PATH/userpatches/overlay-user/etc/wpa_supplicant"
    cat > "$BUILD_PATH/userpatches/overlay-user/etc/wpa_supplicant/wpa_supplicant.conf" <<EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
    priority=100
}
EOF
    chmod 600 "$BUILD_PATH/userpatches/overlay-user/etc/wpa_supplicant/wpa_supplicant.conf"

    mkdir -p "$BUILD_PATH/userpatches/chroot-services-rk3308bs-evb.d"
    cat > "$BUILD_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password" <<EOF
#!/bin/bash
echo "root:$ROOT_PASSWORD" | chpasswd -c SHA512
echo "[rootfs] Root password configured"
EOF
    chmod +x "$BUILD_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password"

    if [ -d "$SCRIPT_DIR/overlay-user" ]; then
        cp -a "$SCRIPT_DIR/overlay-user/." "$BUILD_PATH/userpatches/overlay-user/"
    fi
    if [ -f "$SCRIPT_DIR/userpatches-chroot/20-rk3308bs-hardware.sh" ]; then
        cp "$SCRIPT_DIR/userpatches-chroot/20-rk3308bs-hardware.sh" \
            "$BUILD_PATH/config/20-rk3308bs-hardware.sh"
        chmod +x "$BUILD_PATH/config/20-rk3308bs-hardware.sh"
    fi
    if [ -f "$SCRIPT_DIR/userpatches-customize-image.sh" ]; then
        cp "$SCRIPT_DIR/userpatches-customize-image.sh" \
            "$BUILD_PATH/userpatches/customize-image.sh"
        chmod +x "$BUILD_PATH/userpatches/customize-image.sh"
    fi

    cat > "$BUILD_PATH/userpatches/config.conf" <<EOF
BOARD=rk3308bs-evb
BRANCH=${KERNEL_BRANCH:-current}
RELEASE=${RELEASE:-bookworm}
BUILD_MINIMAL=yes
EXPERT=yes
PREFER_DOCKER=no
EOF
}

# ==================== REMOTE BUILD ==========================================

_build_remote() {
    SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
    PLINK="/mnt/c/Program Files/PuTTY/plink.exe"
    PSCP="/mnt/c/Program Files/PuTTY/pscp.exe"
    REMOTE_PASS="${SSH_PASSWORD:-${SUDO_PASSWORD:-}}"
    USE_PLINK=0
    if [ -n "$REMOTE_PASS" ] && [ -f "$PLINK" ]; then
        USE_PLINK=1
    fi
    SSH_PATH="$BUILD_SERVER_PATH"
    SUDO_PW="${SUDO_PASSWORD:-$REMOTE_PASS}"

    ssh_remote() {
        if [ "$USE_PLINK" = "1" ]; then
            "$PLINK" -batch -pw "$REMOTE_PASS" "$BUILD_SERVER_USER@$BUILD_SERVER_HOST" "$@"
        elif [ -n "${SSHPASS:-}" ] && command -v sshpass >/dev/null 2>&1; then
            sshpass -e ssh $SSH_OPTS "$BUILD_SERVER_USER@$BUILD_SERVER_HOST" "$@"
        else
            ssh $SSH_OPTS "$BUILD_SERVER_USER@$BUILD_SERVER_HOST" "$@"
        fi
    }
    scp_remote() {
        if [ "$USE_PLINK" = "1" ]; then
            local args=()
            for a in "$@"; do
                if [[ "$a" == *@*:* ]]; then
                    args+=("$a")
                elif [[ -e "$a" ]] || [[ -d "$a" ]]; then
                    args+=("$(wslpath -w "$a")")
                else
                    args+=("$a")
                fi
            done
            "$PSCP" -batch -pw "$REMOTE_PASS" "${args[@]}"
        elif [ -n "${SSHPASS:-}" ] && command -v sshpass >/dev/null 2>&1; then
            sshpass -e scp $SSH_OPTS "$@"
        else
            scp $SSH_OPTS "$@"
        fi
    }

    step "PHASE 1: Preparing build server"
    
    if ! ssh_remote true 2>/dev/null; then
        warn "Cannot connect to $BUILD_SERVER_USER@$BUILD_SERVER_HOST"
        return 1
    fi
    info "✓ SSH connection OK"

    info "Ensuring build directory: $SSH_PATH"
    ssh_remote mkdir -p "$SSH_PATH"

    # Initialize or update Armbian repo
    info "Setting up Armbian repository..."
    ssh_remote 'bash -s' <<EOF_INIT_REPO
#!/bin/bash
set -e
BUILD_PATH="$SSH_PATH"

if [ ! -d "\$BUILD_PATH/.git" ]; then
    echo "Cloning Armbian..."
    cd /tmp
    rm -rf armbian-build-clone 2>/dev/null || true
    git clone --depth=1 --branch master https://github.com/armbian/build.git armbian-build-clone
    mv armbian-build-clone/* "\$BUILD_PATH/" 2>/dev/null || true
    mv armbian-build-clone/.* "\$BUILD_PATH/" 2>/dev/null || true
    rm -rf armbian-build-clone
else
    echo "Updating Armbian..."
    cd "\$BUILD_PATH"
    git fetch --depth=1
    git reset --hard origin/master
fi

echo "✓ Armbian repo ready"
EOF_INIT_REPO

    # Copy artifacts
    info "Uploading configuration..."
    scp_remote -q "$SCRIPT_DIR/rk3308bs-evb.conf" \
        "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_board.conf"
    scp_remote -q "$PATCH_FILE" \
        "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_kernel.patch"
    scp_remote -q "$DTS_FILE" \
        "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_device.dts"
    if [ -d "$SCRIPT_DIR/overlay-user" ]; then
        ssh_remote mkdir -p "$SSH_PATH/_overlay-user"
        scp_remote -r -q "$SCRIPT_DIR/overlay-user/" \
            "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_overlay-user/"
    fi
    if [ -f "$SCRIPT_DIR/userpatches-chroot/20-rk3308bs-hardware.sh" ]; then
        scp_remote -q "$SCRIPT_DIR/userpatches-chroot/20-rk3308bs-hardware.sh" \
            "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_hardware-chroot.sh"
    fi
    if [ -f "$SCRIPT_DIR/userpatches-customize-image.sh" ]; then
        scp_remote -q "$SCRIPT_DIR/userpatches-customize-image.sh" \
            "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_customize-image.sh"
    fi
    info "Configuring WiFi and root password..."
    ssh_remote 'bash -s' <<EOF_SETUP
#!/bin/bash
set -e
BUILD_PATH="$SSH_PATH"
WIFI_SSID="$WIFI_SSID"
WIFI_PASSWORD="$WIFI_PASSWORD"
ROOT_PASSWORD="$ROOT_PASSWORD"

# Install config
cp "\$BUILD_PATH/_board.conf" "\$BUILD_PATH/config/boards/rk3308bs-evb.conf"
sed -i 's/\r\$//' "\$BUILD_PATH/config/boards/rk3308bs-evb.conf"

# Install kernel patch
mkdir -p "\$BUILD_PATH/userpatches/kernel/rockchip64-current"
cp "\$BUILD_PATH/_kernel.patch" "\$BUILD_PATH/userpatches/kernel/rockchip64-current/0001-add-rk3308bs-evb.patch"
sed -i 's/\r\$//' "\$BUILD_PATH/userpatches/kernel/rockchip64-current/0001-add-rk3308bs-evb.patch"

# Create WiFi overlay
mkdir -p "\$BUILD_PATH/userpatches/overlay-user/etc/NetworkManager/conf.d"
mkdir -p "\$BUILD_PATH/userpatches/overlay-user/etc/wpa_supplicant"

cat > "\$BUILD_PATH/userpatches/overlay-user/etc/wpa_supplicant/wpa_supplicant.conf" <<'WIFIF'
ctrl_interface=/var/run/wpa_supplicant
update_config=1

network={
    ssid="\$WIFI_SSID"
    psk="\$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
    priority=100
}
WIFIF

chmod 600 "\$BUILD_PATH/userpatches/overlay-user/etc/wpa_supplicant/wpa_supplicant.conf"

# Create root password setup script (runs in chroot)
mkdir -p "\$BUILD_PATH/userpatches/chroot-services-rk3308bs-evb.d"

cat > "\$BUILD_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password" <<'PASSWDF'
#!/bin/bash
# This runs inside chroot during image build
echo "root:\$ROOT_PASSWORD" | chpasswd -c SHA512
echo "[rootfs] Root password configured"
PASSWDF

sed -i "s|\\\$ROOT_PASSWORD|$ROOT_PASSWORD|g" "\$BUILD_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password"
chmod +x "\$BUILD_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password"

# Enable WiFi service
mkdir -p "\$BUILD_PATH/userpatches/overlay-user/etc/systemd/system-sleep"
cat > "\$BUILD_PATH/userpatches/overlay-user/etc/systemd/system-sleep/99-wifi-restart" <<'WWIF'
#!/bin/bash
# Auto-reconnect WiFi after sleep
case \$1 in
    post)
        systemctl restart wpa_supplicant
        ;;
esac
WWIF

chmod +x "\$BUILD_PATH/userpatches/overlay-user/etc/systemd/system-sleep/99-wifi-restart"

# Serial getty @ 1500000 (overlay from repo if present)
if [ -d "\$BUILD_PATH/_overlay-user" ]; then
    cp -a "\$BUILD_PATH/_overlay-user/." "\$BUILD_PATH/userpatches/overlay-user/"
fi

# Board hardware userland (WiFi tools, ttyFIQ0 getty, etc.)
if [ -f "\$BUILD_PATH/_hardware-chroot.sh" ]; then
    cp "\$BUILD_PATH/_hardware-chroot.sh" "\$BUILD_PATH/config/20-rk3308bs-hardware.sh"
    chmod +x "\$BUILD_PATH/config/20-rk3308bs-hardware.sh"
fi
if [ -f "\$BUILD_PATH/_customize-image.sh" ]; then
    cp "\$BUILD_PATH/_customize-image.sh" "\$BUILD_PATH/userpatches/customize-image.sh"
    chmod +x "\$BUILD_PATH/userpatches/customize-image.sh"
fi

# Non-interactive build (avoid config-example.conf interactive prompts)
rm -f "\$BUILD_PATH/userpatches/config-example.conf"
cat > "\$BUILD_PATH/userpatches/config.conf" <<CFG
BOARD=rk3308bs-evb
BRANCH=${KERNEL_BRANCH:-current}
RELEASE=${RELEASE:-bookworm}
BUILD_MINIMAL=yes
EXPERT=yes
PREFER_DOCKER=no
CFG

echo "✓ Configuration ready"
EOF_SETUP

    step "PHASE 2: Building Armbian (this takes 20-40 minutes)"
    step "Server: $BUILD_SERVER_HOST | Build: $SSH_PATH"
    echo ""

    # Invoke build with extended timeout
    if [ -n "$SUDO_PW" ]; then
        COMPILE_WRAP="echo '$SUDO_PW' | sudo -S bash -c"
    else
        COMPILE_WRAP="bash -c"
    fi
    if ssh_remote "cd $SSH_PATH && echo '$SUDO_PW' | sudo -S env CI=true BUILD_ALL=yes timeout 180m bash -c 'EXPERT=yes PREFER_DOCKER=no ./compile.sh BOARD=rk3308bs-evb BRANCH=${KERNEL_BRANCH:-current} RELEASE=${RELEASE:-bookworm} BUILD_MINIMAL=yes'" 2>&1 | tee build-remote.log; then
        BUILD_OK=1
    else
        BUILD_OK=0
    fi

    if [ "$BUILD_OK" != "1" ]; then
        error "Armbian compile failed — see build-remote.log"
    fi

    step "PHASE 3: Retrieving image from server"

    # Find latest image
    LATEST=$(ssh_remote "ls -t $SSH_PATH/output/images/*.img 2>/dev/null | head -1" || echo "")

    if [ -z "$LATEST" ]; then
        # Try compressed
        LATEST=$(ssh_remote "ls -t $SSH_PATH/output/images/*.img.xz 2>/dev/null | head -1" || echo "")
    fi

    if [ -z "$LATEST" ]; then
        error "No output image found on server! Check build-remote.log above"
    fi

    IMG_NAME=$(basename "$LATEST")
    info "Downloading: $IMG_NAME"

    scp_remote -q "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$LATEST" "$SCRIPT_DIR/../$IMG_NAME"

    info ""
    info "═════════════════════════════════════════════"
    info "✅ BUILD COMPLETE"
    info "═════════════════════════════════════════════"
    info "Image: $SCRIPT_DIR/../$IMG_NAME"
    if [ -f "$SCRIPT_DIR/../$IMG_NAME" ]; then
        SIZE=$(du -h "$SCRIPT_DIR/../$IMG_NAME" | cut -f1)
        MD5=$(md5sum "$SCRIPT_DIR/../$IMG_NAME" | cut -d' ' -f1)
        info "Size: $SIZE"
        info "MD5:  $MD5"
    fi
    info ""
    info "WiFi: SSID=$WIFI_SSID"
    info "Root: password set (interactive login)"
    info ""
    info "Next: Build eMMC update for RKDevTool"
    info "  ./build-emmc-release.sh --armbian $SCRIPT_DIR/../$IMG_NAME --version 1.0.0"
    info ""
    return 0
}

# ==================== LOCAL BUILD ==========================================

_ensure_armbian_repo() {
    local BUILD_PATH="$1"
    if [ ! -f "$BUILD_PATH/compile.sh" ]; then
        info "Cloning Armbian build framework (first time only)..."
        git clone --depth=1 --branch main https://github.com/armbian/build.git "$BUILD_PATH"
    fi
}

_build_local() {
    ARMBIAN_PATH="${ARMBIAN_PATH:-$HOME/armbian-build}"
    _ensure_armbian_repo "$ARMBIAN_PATH"
    info "Armbian path: $ARMBIAN_PATH"

    info "Installing board config, DTS patch, overlays..."
    _install_userpatches "$ARMBIAN_PATH"

    step "Starting Armbian compile.sh (20-90 min first run)..."
    cd "$ARMBIAN_PATH"

    ./compile.sh \
        BOARD=rk3308bs-evb \
        BRANCH="${KERNEL_BRANCH:-current}" \
        RELEASE="${RELEASE:-bookworm}" \
        BUILD_MINIMAL=yes \
        EXPERT=yes \
        PREFER_DOCKER=no \
        "$@"

    LATEST="$(ls -t "$ARMBIAN_PATH/output/images/"*.img 2>/dev/null | head -1 || true)"
    if [ -z "$LATEST" ]; then
        LATEST="$(ls -t "$ARMBIAN_PATH/output/images/"*.img.xz 2>/dev/null | head -1 || true)"
    fi
    [ -n "$LATEST" ] || error "No output image in $ARMBIAN_PATH/output/images/"

    OUT_PARENT="$(cd "$SCRIPT_DIR/.." && pwd)"
    IMG_NAME="$(basename "$LATEST")"
    if [[ "$LATEST" == *.xz ]]; then
        info "Decompressing $IMG_NAME ..."
        cp "$LATEST" "$OUT_PARENT/"
        xz -dkf "$OUT_PARENT/$IMG_NAME"
        IMG_NAME="${IMG_NAME%.xz}"
    else
        cp "$LATEST" "$OUT_PARENT/$IMG_NAME"
    fi

    info ""
    info "═════════════════════════════════════════════"
    info "BUILD COMPLETE (from Armbian source)"
    info "═════════════════════════════════════════════"
    info "Image: $OUT_PARENT/$IMG_NAME"
    info "Size:  $(du -h "$OUT_PARENT/$IMG_NAME" | cut -f1)"
    info ""
    info "Next: ./build-emmc-release.sh --armbian \"$OUT_PARENT/$IMG_NAME\" --version 1.0.0"
    info ""
}

case "$BUILD_TYPE" in
    remote)
        step "REMOTE BUILD: $BUILD_SERVER_HOST"
        if ! _build_remote; then
            warn "Remote build failed — falling back to local WSL build"
            step "LOCAL BUILD (fallback)"
            _build_local
        fi
        ;;
    local)
        step "LOCAL BUILD"
        _build_local
        ;;
    *)
        error "Unknown BUILD_SERVER: $BUILD_TYPE (use 'remote' or 'local')"
        ;;
esac

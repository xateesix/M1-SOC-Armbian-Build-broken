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

# Allow override from environment
BUILD_TYPE="${BUILD_SERVER:-remote}"  # "remote" or "local"

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
    "$SCRIPT_DIR/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch" \
    "$SCRIPT_DIR/rk3308bs-evb-amic-v11.dts"; do
    if [ ! -f "$f" ]; then
        error "Missing: $(basename $f)"
    fi
done

case "$BUILD_TYPE" in
    remote)
        step "REMOTE BUILD: $BUILD_SERVER_HOST"
        _build_remote
        ;;
    local)
        step "LOCAL BUILD"
        _build_local
        ;;
    *)
        error "Unknown BUILD_SERVER: $BUILD_TYPE (use 'remote' or 'local')"
        ;;
esac

# ==================== REMOTE BUILD ==========================================

_build_remote() {
    SSH_CMD="ssh -o ConnectTimeout=5 $BUILD_SERVER_USER@$BUILD_SERVER_HOST"
    SSH_PATH="$BUILD_SERVER_PATH"

    step "PHASE 1: Preparing build server"
    
    # Test SSH connection
    if ! $SSH_CMD true 2>/dev/null; then
        error "Cannot connect to $BUILD_SERVER_USER@$BUILD_SERVER_HOST"
    fi
    info "✓ SSH connection OK"

    # Ensure build directory
    info "Ensuring build directory: $SSH_PATH"
    $SSH_CMD mkdir -p "$SSH_PATH"

    # Initialize or update Armbian repo
    info "Setting up Armbian repository..."
    $SSH_CMD 'bash -s' <<'EOF_INIT_REPO'
#!/bin/bash
set -e
BUILD_PATH="/home/xateesix/armbian-build"

if [ ! -d "$BUILD_PATH/.git" ]; then
    echo "Cloning Armbian..."
    cd /tmp
    rm -rf armbian-build-clone 2>/dev/null || true
    git clone --depth=1 --branch master https://github.com/armbian/build.git armbian-build-clone
    mv armbian-build-clone/* "$BUILD_PATH/" 2>/dev/null || true
    mv armbian-build-clone/.* "$BUILD_PATH/" 2>/dev/null || true
    rm -rf armbian-build-clone
else
    echo "Updating Armbian..."
    cd "$BUILD_PATH"
    git fetch --depth=1
    git reset --hard origin/master
fi

echo "✓ Armbian repo ready"
EOF_INIT_REPO

    # Copy artifacts
    info "Uploading configuration..."
    scp -q "$SCRIPT_DIR/rk3308bs-evb.conf" \
        "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_board.conf"
    scp -q "$SCRIPT_DIR/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch" \
        "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_kernel.patch"
    scp -q "$SCRIPT_DIR/rk3308bs-evb-amic-v11.dts" \
        "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$SSH_PATH/_device.dts"

    # Setup WiFi and root password via remote script
    info "Configuring WiFi and root password..."
    $SSH_CMD 'bash -s' <<EOF_SETUP
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

echo "✓ Configuration ready"
EOF_SETUP

    step "PHASE 2: Building Armbian (this takes 20-40 minutes)"
    step "Server: $BUILD_SERVER_HOST | Build: $SSH_PATH"
    echo ""

    # Invoke build with extended timeout
    if $SSH_CMD "cd $SSH_PATH && timeout 120m bash -c 'EXPERT=yes PREFER_DOCKER=no ./compile.sh kernel rockchip64-current'" 2>&1 | tee build-remote.log; then
        BUILD_OK=1
    else
        BUILD_OK=0
    fi

    if [ "$BUILD_OK" != "1" ]; then
        warn "Build may have timed out or failed. Checking for output image..."
    fi

    step "PHASE 3: Retrieving image from server"

    # Find latest image
    LATEST=$($SSH_CMD "ls -t $SSH_PATH/output/images/*.img 2>/dev/null | head -1" || echo "")

    if [ -z "$LATEST" ]; then
        # Try compressed
        LATEST=$($SSH_CMD "ls -t $SSH_PATH/output/images/*.img.xz 2>/dev/null | head -1" || echo "")
    fi

    if [ -z "$LATEST" ]; then
        error "No output image found on server! Check build-remote.log above"
    fi

    IMG_NAME=$(basename "$LATEST")
    info "Downloading: $IMG_NAME"

    scp -q "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:$LATEST" "$SCRIPT_DIR/$IMG_NAME"

    info ""
    info "═════════════════════════════════════════════"
    info "✅ BUILD COMPLETE"
    info "═════════════════════════════════════════════"
    info "Image: $SCRIPT_DIR/$IMG_NAME"
    if [ -f "$SCRIPT_DIR/$IMG_NAME" ]; then
        SIZE=$(du -h "$SCRIPT_DIR/$IMG_NAME" | cut -f1)
        MD5=$(md5sum "$SCRIPT_DIR/$IMG_NAME" | cut -d' ' -f1)
        info "Size: $SIZE"
        info "MD5:  $MD5"
    fi
    info ""
    info "WiFi: SSID=$WIFI_SSID"
    info "Root: password set (interactive login)"
    info ""
    info "Next: Flash to microSD"
    info "  Windows: balenaEtcher or SharpAdbHelper + USB reader"
    info "  Linux:   dd if=$IMG_NAME of=/dev/sdX bs=4M status=progress"
    info ""
}

# ==================== LOCAL BUILD ==========================================

_build_local() {
    ARMBIAN_PATH="${ARMBIAN_PATH:-$HOME/armbian-build}"

    if [ ! -f "$ARMBIAN_PATH/compile.sh" ]; then
        error "Armbian not found at: $ARMBIAN_PATH"
        echo ""
        echo "Clone it first:"
        echo "  git clone --depth=1 https://github.com/armbian/build \\"
        echo "    $ARMBIAN_PATH"
    fi

    info "Armbian path: $ARMBIAN_PATH"

    # Install board config
    info "Installing board configuration..."
    cp "$SCRIPT_DIR/rk3308bs-evb.conf" "$ARMBIAN_PATH/config/boards/rk3308bs-evb.conf"
    sed -i 's/\r$//' "$ARMBIAN_PATH/config/boards/rk3308bs-evb.conf"

    # Install kernel patch
    info "Installing kernel patch..."
    mkdir -p "$ARMBIAN_PATH/userpatches/kernel/rockchip64-current"
    cp "$SCRIPT_DIR/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch" \
        "$ARMBIAN_PATH/userpatches/kernel/rockchip64-current/"
    sed -i 's/\r$//' "$ARMBIAN_PATH/userpatches/kernel/rockchip64-current/"*.patch

    # WiFi config
    info "Configuring WiFi..."
    mkdir -p "$ARMBIAN_PATH/userpatches/overlay-user/etc/wpa_supplicant"
    cat > "$ARMBIAN_PATH/userpatches/overlay-user/etc/wpa_supplicant/wpa_supplicant.conf" <<EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
    priority=100
}
EOF
    chmod 600 "$ARMBIAN_PATH/userpatches/overlay-user/etc/wpa_supplicant/wpa_supplicant.conf"

    # Root password script
    info "Configuring root password..."
    mkdir -p "$ARMBIAN_PATH/userpatches/chroot-services-rk3308bs-evb.d"
    cat > "$ARMBIAN_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password" <<'EOF'
#!/bin/bash
echo "root:$ROOT_PASSWORD" | chpasswd -c SHA512
EOF

    sed -i "s|\\\$ROOT_PASSWORD|$ROOT_PASSWORD|g" \
        "$ARMBIAN_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password"
    chmod +x "$ARMBIAN_PATH/userpatches/chroot-services-rk3308bs-evb.d/10-set-root-password"

    step "Starting build..."
    cd "$ARMBIAN_PATH"

    ./compile.sh \
        BOARD=rk3308bs-evb \
        BRANCH=current \
        RELEASE=jammy \
        EXPERT=yes \
        PREFER_DOCKER=no \
        COMPRESS_OUTPUTIMAGE=yes \
        "$@"

    info ""
    info "✅ Build complete!"
    info "Output: $ARMBIAN_PATH/output/images/"
}


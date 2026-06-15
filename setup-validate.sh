#!/bin/bash
# =============================================================================
# Setup Validator and Prerequisites Check
#
# Run this before your first build to ensure all files and SSH access work
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
check()  { echo -e "${BLUE}[CHECK]${NC} $*"; }
ok()     { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()   { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
fail()   { echo -e "${RED}[ FAIL ]${NC} $*"; }

echo "═════════════════════════════════════════════════════════════════"
echo "RK3308BS Armbian Build System - Setup Validator"
echo "═════════════════════════════════════════════════════════════════"
echo ""

# ──────────────────────────────────────────────────────────────────────────
# Check 1: Configuration File
# ──────────────────────────────────────────────────────────────────────────
check "1. Configuration file..."

if [ ! -f "$CONFIG_FILE" ]; then
    fail "Missing config.env"
    echo ""
    echo "Create it with:"
    echo "  ./configure.sh"
    echo "  # Edit with your WiFi/root password"
    exit 1
fi

ok "config.env found"

# Source it
source "$CONFIG_FILE" || {
    fail "config.env is invalid (syntax error)"
    exit 1
}

# Check required variables
for var in ROOT_PASSWORD; do
    if [ -z "${!var:-}" ]; then
        fail "Missing $var in config.env"
        exit 1
    fi
done

ok "All required variables set"

# ──────────────────────────────────────────────────────────────────────────
# Check 2: Local Files
# ──────────────────────────────────────────────────────────────────────────
check "2. Device tree and patches..."

FILES=(
    "$SCRIPT_DIR/rk3308bs-evb.conf"
    "$SCRIPT_DIR/0001-arm64-dts-rockchip-add-rk3308bs-evb-amic-v11.patch"
    "$SCRIPT_DIR/rk3308bs-evb-amic-v11.dts"
    "$SCRIPT_DIR/build-enhanced.sh"
)

for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        fail "Missing: $(basename $f)"
        exit 1
    fi
    ok "$(basename $f) OK"
done

# ──────────────────────────────────────────────────────────────────────────
# Check 3: SSH Connectivity
# ──────────────────────────────────────────────────────────────────────────
check "3. SSH connectivity to $BUILD_SERVER_USER@$BUILD_SERVER_HOST..."

if ! ssh -o ConnectTimeout=10 -o BatchMode=yes \
    "$BUILD_SERVER_USER@$BUILD_SERVER_HOST" "echo SSH_OK" &>/dev/null; then
    fail "Cannot connect via SSH"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify server address: $BUILD_SERVER_HOST"
    echo "  2. Verify username: $BUILD_SERVER_USER"
    echo "  3. Check SSH key is in ~/.ssh/"
    echo "  4. Try manually: ssh $BUILD_SERVER_USER@$BUILD_SERVER_HOST"
    echo ""
    echo "Setup SSH key:"
    echo "  ssh-keygen -t ed25519"
    echo "  ssh-copy-id $BUILD_SERVER_USER@$BUILD_SERVER_HOST"
    exit 1
fi

ok "SSH access OK"

# ──────────────────────────────────────────────────────────────────────────
# Check 4: Build Server Status
# ──────────────────────────────────────────────────────────────────────────
check "4. Build server environment..."

ssh "$BUILD_SERVER_USER@$BUILD_SERVER_HOST" 'bash -s' <<'EOF_SERVER_CHECK'
#!/bin/bash

echo "[Server] Checking prerequisites..."

# Git
if ! command -v git &>/dev/null; then
    echo "[FAIL] git not installed"
    exit 1
fi
echo "[OK] git $(git --version | cut -d' ' -f3)"

# Build tools
if ! command -v bc &>/dev/null; then
    echo "[WARN] bc not found (needed for builds)"
fi

# Disk space
AVAIL=$(df /home | awk 'NR==2 {print $4}')
if [ "$AVAIL" -lt 10485760 ]; then  # <10GB
    echo "[WARN] Only ${AVAIL}KB free (recommend 20GB+)"
else
    echo "[OK] Disk space: $(numfmt --to=iec $((AVAIL * 1024)) 2>/dev/null || echo "${AVAIL}KB")"
fi

echo "[OK] Server is ready"
EOF_SERVER_CHECK

ok "Build server OK"

# ──────────────────────────────────────────────────────────────────────────
# Check 5: Build Directory Ready
# ──────────────────────────────────────────────────────────────────────────
check "5. Build directory..."

ssh "$BUILD_SERVER_USER@$BUILD_SERVER_HOST" "mkdir -p '$BUILD_SERVER_PATH'" || {
    fail "Cannot create build directory"
    exit 1
}

ok "Build directory: $BUILD_SERVER_PATH ready"

# ──────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────
echo ""
echo "═════════════════════════════════════════════════════════════════"
echo "✅ All Checks Passed!"
echo "═════════════════════════════════════════════════════════════════"
echo ""
echo "Configuration Summary:"
echo "  Build Server: $BUILD_SERVER_USER@$BUILD_SERVER_HOST"
echo "  Build Path:   $BUILD_SERVER_PATH"
echo "  WiFi SSID:    $WIFI_SSID"
echo "  Root Password: [configured]"
echo ""
echo "Next Steps:"
echo "  1. Review config.env"
echo "  2. Run: ./build-enhanced.sh"
echo "  3. Image will download to: $SCRIPT_DIR/"
echo ""
echo "For help, see:"
echo "  - README.md"
echo "  - GITHUB_SETUP.md"
echo ""

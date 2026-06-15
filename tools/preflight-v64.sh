#!/usr/bin/env bash
# Verify host tools and release tarball inputs for the v64 pipeline.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO/config.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
check() { echo -e "${BLUE}[CHECK]${NC} $*"; }
ok()    { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
fail()  { echo -e "${RED}[ FAIL ]${NC} $*"; exit 1; }

echo "=== v64 build preflight ==="

check "config.env"
[[ -f "$CONFIG" ]] || fail "Missing config.env  -  run ./configure.sh or copy config.env.example"
ok "config.env present"

if [[ -z "${BUILD_ARTIFACTS_URL:-}" ]]; then
  warn "BUILD_ARTIFACTS_URL not set  -  required unless artifacts already downloaded"
fi

check "host build dependencies"
bash "$SCRIPT_DIR/install-build-deps.sh"
ok "host dependencies"

check "release tarball inputs"
bash "$SCRIPT_DIR/fetch-build-sources.sh" || fail "fetch-build-sources.sh failed"

REL="$REPO/releases/1.0.0"
FAC_PART="$REPO/factory_fresh/03_partitions"
FAC_BOOT="$REPO/factory_fresh/04_boot_unpacked"
for f in \
  "$REL/_Image-v22" \
  "$REL/rootfs-v61.img" \
  "$REL/_uboot-memlayout.img" \
  "$FAC_BOOT/resource.img" \
  "$FAC_PART/MiniLoaderAll.bin" \
  "$REL/_modules_6.18.0-dirty/kernel/drivers/leds/leds-pwm.ko"; do
  [[ -f "$f" ]] || fail "Missing $f"
done
ok "all release inputs present"

echo ""
ok "Preflight passed  -  run: bash tools/build-release-v64.sh"
echo "Note: final pack and flash require RKDevTool on Windows (see README.md)."
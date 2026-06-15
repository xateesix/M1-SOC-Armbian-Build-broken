#!/usr/bin/env bash
# v44 was never released (build blocked on WSL sudo). Use v45 instead.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "ERROR: There is no v44 firmware image  -  v44 build never completed."
echo "Use: bash tools/build-release-v45-rootfs-only.sh"
echo "  (v45 = safe chroot rootfs + system.cfg; fixes v43 ext4 inode corruption)"
exec bash "$SCRIPT_DIR/tools/build-release-v45-rootfs-only.sh"

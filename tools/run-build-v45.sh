#!/usr/bin/env bash
# Run v45 build as WSL root (loop mount + ARM64 chroot via qemu-user-static).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TMPDIR="$SCRIPT_DIR/.wsl-tmp"
mkdir -p "$TMPDIR"
bash "$SCRIPT_DIR/tools/build-release-v45-rootfs-only.sh" 2>&1 | tee "$TMPDIR/build-v45.log"

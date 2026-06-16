#!/usr/bin/env bash
# Rebuild public v64 flash image: m1prox1/m1prox1, no WiFi.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
TOOLS="$SCRIPT_DIR/tools"
LOG="$SCRIPT_DIR/rebuild-public-v64.log"

exec > >(tee -a "$LOG") 2>&1
echo "=== rebuild-public-v64 started $(date -Is) ==="

[[ -f "$REL/rootfs-v61-private.bak" ]] || { echo "Missing $REL/rootfs-v61-private.bak"; exit 1; }

bash "$TOOLS/patch-rootfs-public-credentials-debugfs.sh" \
  "$REL/rootfs-v61-private.bak" "$REL/rootfs-v61-public.img"

cp -f "$REL/rootfs-v61-public.img" "$REL/rootfs-v61.img"

bash "$TOOLS/build-release-v64.sh"

debugfs -R "dump /etc/passwd /tmp/rkverify" "$REL/rootfs-v64.img"
grep -E '^(root|m1prox)' /tmp/rkverify

echo "=== rebuild-public-v64 finished $(date -Is) ==="
echo "Output: $REL/rk3308bs-1.0.0-emmc-fixed-v64.img"

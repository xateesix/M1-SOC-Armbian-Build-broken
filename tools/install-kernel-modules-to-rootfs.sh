#!/usr/bin/env bash
# Copy freshly built 6.18.0-dirty modules into ext4 rootfs (needs sudo loop mount).
set -euo pipefail
REPO="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian"
REL="$REPO/releases/1.0.0"
SRC_ROOTFS="${1:-$REL/rootfs-v15.img}"
OUT_ROOTFS="${2:-$REL/rootfs-v16.img}"
MOD_SRC="${3:-$REL/_modules_6.18.0-dirty}"

[[ -d "$MOD_SRC/lib/modules" ]] || { echo "Missing modules: $MOD_SRC"; exit 1; }
[[ -f "$SRC_ROOTFS" ]] || { echo "Missing rootfs: $SRC_ROOTFS"; exit 1; }

if ! sudo -n true 2>/dev/null; then
  echo "Need sudo for loop mount to install kernel modules."
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'sudo umount "$MNT" 2>/dev/null || true; rm -rf "$WORKDIR"' EXIT

cp "$SRC_ROOTFS" "$WORKDIR/rootfs.img"
MNT="$WORKDIR/mnt"
mkdir -p "$MNT"
sudo mount -o loop "$WORKDIR/rootfs.img" "$MNT"

KVER="$(ls "$MOD_SRC/lib/modules")"
rm -rf "$MNT/lib/modules/$KVER"
mkdir -p "$MNT/lib/modules"
cp -a "$MOD_SRC/lib/modules/$KVER" "$MNT/lib/modules/"

# Prefer our kernel in module path
ln -sfn "$KVER" "$MNT/lib/modules/6.18.0-dirty" 2>/dev/null || true

# Auto-load display stack on boot
mkdir -p "$MNT/etc/modules-load.d"
cat >"$MNT/etc/modules-load.d/rk3308bs-display.conf" <<'EOF'
rockchipdrm
drm_kms_helper
drm
panel_simple
backlight
pwm_bl
EOF

sudo depmod -b "$MNT" "$KVER" 2>/dev/null || true
sudo umount "$MNT"
cp "$WORKDIR/rootfs.img" "$OUT_ROOTFS"
trap - EXIT
rm -rf "$WORKDIR"
echo "Wrote $OUT_ROOTFS with modules for $KVER"

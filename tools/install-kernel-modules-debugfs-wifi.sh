#!/usr/bin/env bash
# Install WiFi .ko modules via debugfs (no sudo loop mount).
set -euo pipefail
REPO="/mnt/c/Users/john.X86/Downloads/RKDevTool_Release_v2.86/RKDevTool_Release_v2.86/Output/Armbian"
REL="$REPO/releases/1.0.0"
SRC_ROOTFS="${1:-$REL/rootfs-v22-patched.img}"
OUT_ROOTFS="${2:-$REL/rootfs-v22.img}"
MOD_SRC="${3:-$REL/_modules_6.18.0-dirty}"
KVER="6.18.0-dirty"
MOD_BASE="/usr/lib/modules/${KVER}"

[[ -f "$SRC_ROOTFS" ]] || { echo "Missing $SRC_ROOTFS"; exit 1; }
[[ -d "$MOD_SRC/lib/modules/$KVER" ]] || { echo "Missing modules for $KVER"; exit 1; }

declare -A MODS=(
  ["kernel/lib/crypto/libarc4.ko"]="$MOD_SRC/lib/modules/$KVER/kernel/lib/crypto/libarc4.ko"
  ["kernel/net/wireless/cfg80211.ko"]="$MOD_SRC/lib/modules/$KVER/kernel/net/wireless/cfg80211.ko"
  ["kernel/net/mac80211/mac80211.ko"]="$MOD_SRC/lib/modules/$KVER/kernel/net/mac80211/mac80211.ko"
  ["kernel/net/rfkill/rfkill.ko"]="$MOD_SRC/lib/modules/$KVER/kernel/net/rfkill/rfkill.ko"
  ["kernel/drivers/net/wireless/rtl8189fs/8189fs.ko"]="$MOD_SRC/lib/modules/$KVER/kernel/drivers/net/wireless/rtl8189fs/8189fs.ko"
)

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cp "$SRC_ROOTFS" "$WORKDIR/rootfs.img"
DST="$WORKDIR/rootfs.img"

LOAD_SH="$WORKDIR/rk3308bs-load-wifi.sh"
cat >"$LOAD_SH" <<EOF
#!/bin/bash
set -euo pipefail
M=${MOD_BASE}/kernel
# deps order from modules.dep (rfkill before cfg80211; libarc4 before mac80211)
insmod "\$M/net/rfkill/rfkill.ko"
insmod "\$M/lib/crypto/libarc4.ko"
insmod "\$M/net/wireless/cfg80211.ko"
insmod "\$M/net/mac80211/mac80211.ko"
insmod "\$M/drivers/net/wireless/rtl8189fs/8189fs.ko"
EOF

MODULES_DEP="$WORKDIR/modules.dep"
cat >"$MODULES_DEP" <<EOF
kernel/net/rfkill/rfkill.ko:
kernel/lib/crypto/libarc4.ko:
kernel/net/wireless/cfg80211.ko: kernel/net/rfkill/rfkill.ko
kernel/net/mac80211/mac80211.ko: kernel/net/wireless/cfg80211.ko kernel/lib/crypto/libarc4.ko
kernel/drivers/net/wireless/rtl8189fs/8189fs.ko: kernel/net/wireless/cfg80211.ko kernel/net/rfkill/rfkill.ko
EOF

LOAD_UNIT="$WORKDIR/rk3308bs-wifi-modules.service"
cat >"$LOAD_UNIT" <<'EOF'
[Unit]
Description=RK3308BS load 8189fs WiFi modules before networking
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target systemd-networkd.service

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/sbin/rk3308bs-load-wifi.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

declare -A MKDONE=()
mkdir_p() {
	local path="$1"
	local acc=""
	IFS='/' read -r -a parts <<<"${path#/}"
	for part in "${parts[@]}"; do
		acc="${acc}/${part}"
		[[ -n "${MKDONE[$acc]:-}" ]] && continue
		MKDONE[$acc]=1
		echo "mkdir $acc" >>"$CMD"
	done
}

CMD="$WORKDIR/debugfs.cmd"
: >"$CMD"
mkdir_p "/usr/lib/modules/${KVER}"
mkdir_p "/usr/lib/modules/${KVER}/kernel"
for rel in "${!MODS[@]}"; do
	src="${MODS[$rel]}"
	dir="${MOD_BASE}/$(dirname "$rel")"
	mkdir_p "$dir"
	echo "write $src ${MOD_BASE}/$rel" >>"$CMD"
done
cat >>"$CMD" <<EOF
write $MODULES_DEP /usr/lib/modules/${KVER}/modules.dep
write $LOAD_SH /usr/local/sbin/rk3308bs-load-wifi.sh
write $LOAD_UNIT /etc/systemd/system/rk3308bs-wifi-modules.service
quit
EOF

debugfs -w "$DST" -f "$CMD" 2>&1 | grep -v 'already exists' || true
cp "$DST" "$OUT_ROOTFS"
echo "Wrote $OUT_ROOTFS with ${KVER} WiFi modules (debugfs, insmod fallback)"

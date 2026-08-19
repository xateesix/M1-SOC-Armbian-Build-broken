#!/usr/bin/env bash
# Integrate jwrdegoede rtl8189fs driver into kernel tree (same as Armbian drivers_network.sh).
set -euo pipefail

KDIR="${1:-$HOME/linux-v13-build}"
AB="${2:-${ARMBIAN_BUILD_PATH:-/home/xateesix/scratch/Projects/rk3308bs-workspace/M1-SOC-Armbian-Build}}"
COMMIT="876e627a5b6a8021700391b4249a4a31edfebe5c"
CACHE="$(mktemp -d)"
trap 'rm -rf "$CACHE"' EXIT

[[ -d "$KDIR" ]] || { echo "Missing kernel tree: $KDIR"; exit 1; }
[[ -d "$AB/patch/misc" ]] || { echo "Missing Armbian patches: $AB"; exit 1; }

echo "Fetching rtl8189fs @ ${COMMIT:0:12}..."
git clone --quiet https://github.com/jwrdegoede/rtl8189ES_linux "$CACHE/repo"
git -C "$CACHE/repo" fetch --quiet --depth 1 origin "$COMMIT"
git -C "$CACHE/repo" checkout --quiet "$COMMIT"
SRC="$CACHE/repo"

cd "$KDIR"
rm -rf drivers/net/wireless/rtl8189fs
mkdir -p drivers/net/wireless/rtl8189fs
cp -R "$SRC"/{core,hal,include,os_dep,platform} drivers/net/wireless/rtl8189fs/
cp "$SRC/Makefile" "$SRC/Kconfig" drivers/net/wireless/rtl8189fs/
sed -i 's/---help---/help/g' drivers/net/wireless/rtl8189fs/Kconfig
sed -i 's/^CONFIG_RTW_DEBUG.*/CONFIG_RTW_DEBUG = n/' drivers/net/wireless/rtl8189fs/Makefile

grep -q 'rtl8189fs/Kconfig' drivers/net/wireless/Kconfig || \
	sed -i '/source "drivers\/net\/wireless\/ti\/Kconfig"/a source "drivers\/net\/wireless\/rtl8189fs\/Kconfig"' \
		drivers/net/wireless/Kconfig
grep -q 'rtl8189fs/' drivers/net/wireless/Makefile || \
	echo 'obj-$(CONFIG_RTL8189FS) += rtl8189fs/' >> drivers/net/wireless/Makefile

for p in \
	wireless-rtl8189fs-fix-p2p-go-advertising.patch \
	wireless-rtl8189fs-Fix-VFS-import.patch \
	wireless-rtl8189fs-Fix-building-on-5.4.251-kernel.patch; do
	echo "Applying $p..."
	patch -p1 --forward < "$AB/patch/misc/$p" || true
done

echo "rtl8189fs integrated into $KDIR"

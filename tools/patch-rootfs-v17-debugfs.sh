#!/usr/bin/env bash
# Patch rootfs without sudo: fixed GPT layout + baked root/user passwords (no firstlogin wizard).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v17.img}"

[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG"; exit 1; }
[[ -f "$SRC" ]] || { echo "Missing rootfs: $SRC"; exit 1; }
command -v debugfs >/dev/null || { echo "Install e2fsprogs (debugfs)"; exit 1; }
command -v openssl >/dev/null || { echo "Install openssl"; exit 1; }

# shellcheck source=/dev/null
source "$CONFIG"
USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
USER_NAME="${USER_NAME:-xateesix}"
USER_REALNAME="${USER_REALNAME:-$USER_NAME}"
LOCALE="${LOCALE:-en_US.UTF-8}"
TIMEZONE="${TIMEZONE:-America/Los_Angeles}"

ROOT_HASH="$(openssl passwd -6 "$ROOT_PASSWORD")"
USER_HASH="$(openssl passwd -6 "$USER_PASSWORD")"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DST="$WORKDIR/rootfs.img"
NO_RESIZE="$WORKDIR/no_rootfs_resize"
SHADOW="$WORKDIR/shadow"
PASSWD="$WORKDIR/passwd"
GROUP="$WORKDIR/group"

cp "$SRC" "$DST"
: >"$NO_RESIZE"

debugfs -R "dump /etc/shadow $SHADOW" "$DST"
debugfs -R "dump /etc/passwd $PASSWD" "$DST"
debugfs -R "dump /etc/group $GROUP" "$DST"

awk -F: -v h="$ROOT_HASH" 'BEGIN{OFS=":"} $1=="root"{$2=h}1' "$SHADOW" >"$WORKDIR/shadow.new"
if grep -q "^${USER_NAME}:" "$SHADOW"; then
	awk -F: -v h="$USER_HASH" -v u="$USER_NAME" 'BEGIN{OFS=":"} $1==u{$2=h}1' "$WORKDIR/shadow.new" >"$WORKDIR/shadow.tmp"
else
	grep -v "^${USER_NAME}:" "$WORKDIR/shadow.new" >"$WORKDIR/shadow.tmp" || true
	echo "${USER_NAME}:${USER_HASH}:20614:0:99999:7:::" >>"$WORKDIR/shadow.tmp"
fi
mv "$WORKDIR/shadow.tmp" "$WORKDIR/shadow.new"

cp "$PASSWD" "$WORKDIR/passwd.new"
if ! grep -q "^${USER_NAME}:" "$WORKDIR/passwd.new"; then
	echo "${USER_NAME}:x:1000:1000:${USER_REALNAME}:/home/${USER_NAME}:/bin/bash" >>"$WORKDIR/passwd.new"
fi

cp "$GROUP" "$WORKDIR/group.new"
if ! grep -q "^${USER_NAME}:" "$WORKDIR/group.new"; then
	echo "${USER_NAME}:x:1000:" >>"$WORKDIR/group.new"
fi
for g in sudo adm dialout cdrom audio video plugdev games users input render netdev; do
	if grep -q "^${g}:" "$WORKDIR/group.new"; then
		awk -F: -v g="$g" -v u="$USER_NAME" '
			BEGIN{OFS=":"}
			$1==g {
				if ($4 == "") { $4=u }
				else if ($4 !~ "(^|,)" u "(,|$)") { $4=$4 "," u }
			}
			{ print }
		' "$WORKDIR/group.new" >"$WORKDIR/group.tmp" && mv "$WORKDIR/group.tmp" "$WORKDIR/group.new"
	fi
done

LOCALE_GEN="$WORKDIR/locale.gen"
debugfs -R "dump /etc/locale.gen $LOCALE_GEN" "$DST" 2>/dev/null || : >"$LOCALE_GEN"
if grep -q "^# ${LOCALE} UTF-8" "$LOCALE_GEN" 2>/dev/null; then
	sed -i "s/^# ${LOCALE} UTF-8/${LOCALE} UTF-8/" "$LOCALE_GEN"
elif ! grep -q "^${LOCALE} UTF-8" "$LOCALE_GEN" 2>/dev/null; then
	echo "${LOCALE} UTF-8" >>"$LOCALE_GEN"
fi

cat >"$WORKDIR/default.locale" <<EOF
LANG=${LOCALE}
LANGUAGE=${LOCALE}
LC_ALL=${LOCALE}
EOF
echo "$TIMEZONE" >"$WORKDIR/timezone"

CMD="$WORKDIR/debugfs.cmd"
cat >"$CMD" <<EOF
write $NO_RESIZE /root/.no_rootfs_resize
rm /root/.not_logged_in_yet
rm /etc/shadow
write $WORKDIR/shadow.new /etc/shadow
rm /etc/passwd
write $WORKDIR/passwd.new /etc/passwd
rm /etc/group
write $WORKDIR/group.new /etc/group
rm /etc/default/locale
write $WORKDIR/default.locale /etc/default/locale
rm /etc/locale.gen
write $WORKDIR/locale.gen /etc/locale.gen
rm /etc/timezone
write $WORKDIR/timezone /etc/timezone
rm /etc/systemd/system/getty@.service.d/override.conf
rm /etc/systemd/system/serial-getty@.service.d/override.conf
unlink /etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service
cd /etc/systemd/system
symlink /dev/null armbian-resize-filesystem.service
mkdir /home/${USER_NAME}
quit
EOF
debugfs -w "$DST" -f "$CMD"

for skel in .bashrc .profile .bash_logout; do
	SKEL="$WORKDIR/skel_${skel//\./_}"
	if debugfs -R "dump /etc/skel/${skel} $SKEL" "$DST" 2>/dev/null; then
		debugfs -w "$DST" -R "write $SKEL /home/${USER_NAME}/${skel}" 2>/dev/null || true
	fi
done

debugfs -w "$DST" <<EOF
set_inode_field /home/${USER_NAME} uid 1000
set_inode_field /home/${USER_NAME} gid 1000
set_inode_field /home/${USER_NAME} mode 0700
EOF

for skel in .bashrc .profile .bash_logout; do
	debugfs -w "$DST" -R "set_inode_field /home/${USER_NAME}/${skel} uid 1000" 2>/dev/null || true
	debugfs -w "$DST" -R "set_inode_field /home/${USER_NAME}/${skel} gid 1000" 2>/dev/null || true
done

cp "$DST" "$OUT"
echo "Wrote $OUT (baked login: root+${USER_NAME}, no autologin, no wizard, no resize)"

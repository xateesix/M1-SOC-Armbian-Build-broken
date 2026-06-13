#!/usr/bin/env bash
# Patch rootfs without sudo: fixed GPT layout + baked root/user passwords (no firstlogin wizard).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="$SCRIPT_DIR/config.env"
SRC="${1:-$REL/rootfs-v11.img}"
OUT="${2:-$REL/rootfs-v20.img}"
IMAGE_TAG="${RK3308BS_IMAGE_TAG:-v20-serial-autologin}"

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

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/rk3308bs-rootfs.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

DST="$WORKDIR/rootfs.img"
NO_RESIZE="$WORKDIR/no_rootfs_resize"
SHADOW="$WORKDIR/shadow"
PASSWD="$WORKDIR/passwd"
GROUP="$WORKDIR/group"
GSHADOW="$WORKDIR/gshadow"
SUBUID="$WORKDIR/subuid"
SUBGID="$WORKDIR/subgid"

cp "$SRC" "$DST"
: >"$NO_RESIZE"

debugfs -R "dump /etc/shadow $SHADOW" "$DST"
debugfs -R "dump /etc/passwd $PASSWD" "$DST"
debugfs -R "dump /etc/group $GROUP" "$DST"
debugfs -R "dump /etc/gshadow $GSHADOW" "$DST" 2>/dev/null || : >"$GSHADOW"
debugfs -R "dump /etc/subuid $SUBUID" "$DST" 2>/dev/null || : >"$SUBUID"
debugfs -R "dump /etc/subgid $SUBGID" "$DST" 2>/dev/null || : >"$SUBGID"

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

cp "$GSHADOW" "$WORKDIR/gshadow.new"
if ! grep -q "^${USER_NAME}:" "$WORKDIR/gshadow.new"; then
	echo "${USER_NAME}:!::" >>"$WORKDIR/gshadow.new"
fi
for g in sudo adm dialout cdrom audio video plugdev games users input render netdev; do
	if grep -q "^${g}:" "$WORKDIR/gshadow.new"; then
		awk -F: -v g="$g" -v u="$USER_NAME" '
			BEGIN{OFS=":"}
			$1==g {
				if ($4 == "") { $4=u }
				else if ($4 !~ "(^|,)" u "(,|$)") { $4=$4 "," u }
			}
			{ print }
		' "$WORKDIR/gshadow.new" >"$WORKDIR/gshadow.tmp" && mv "$WORKDIR/gshadow.tmp" "$WORKDIR/gshadow.new"
	fi
done

cp "$SUBUID" "$WORKDIR/subuid.new" 2>/dev/null || : >"$WORKDIR/subuid.new"
if ! grep -q "^${USER_NAME}:" "$WORKDIR/subuid.new"; then
	echo "${USER_NAME}:100000:65536" >>"$WORKDIR/subuid.new"
fi
cp "$SUBGID" "$WORKDIR/subgid.new" 2>/dev/null || : >"$WORKDIR/subgid.new"
if ! grep -q "^${USER_NAME}:" "$WORKDIR/subgid.new"; then
	echo "${USER_NAME}:100000:65536" >>"$WORKDIR/subgid.new"
fi

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

cat >"$WORKDIR/default.keyboard" <<'EOF'
# US English keyboard (baked at image build — no console-setup wizard)
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

cat >"$WORKDIR/console-setup" <<'EOF'
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Uni2"
FONTFACE="Fixed"
FONTSIZE="8x16"
VIDEOMODE=
EOF

cat >"$WORKDIR/issue" <<EOF
RK3308BS Armbian ${IMAGE_TAG}
Serial: auto-login ${USER_NAME} on ttyS3
Password login: ${USER_NAME} / ${USER_PASSWORD}
Locale: ${LOCALE} | TZ: ${TIMEZONE} | Keyboard: US
Image stamp: /etc/rk3308bs-release

EOF

cat >"$WORKDIR/rk3308bs-release" <<EOF
RK3308BS_IMAGE=${IMAGE_TAG}
RK3308BS_USER=${USER_NAME}
RK3308BS_SERIAL_AUTOLOGIN=${USER_NAME}
RK3308BS_LOCALE=${LOCALE}
RK3308BS_TZ=${TIMEZONE}
EOF

echo "rk3308bs-${IMAGE_TAG}" >"$WORKDIR/hostname"

cat >"$WORKDIR/serial-autologin.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --keep-baud 115200,1500000,9600 --noclear %I \$TERM
Type=idle
EOF

for f in shadow.new passwd.new group.new gshadow.new subuid.new subgid.new locale.gen default.locale timezone default.keyboard console-setup issue rk3308bs-release hostname serial-autologin.conf; do
	[[ -f "$WORKDIR/$f" ]] && sed -i 's/\r$//' "$WORKDIR/$f"
done

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
rm /etc/gshadow
write $WORKDIR/gshadow.new /etc/gshadow
rm /etc/subuid
write $WORKDIR/subuid.new /etc/subuid
rm /etc/subgid
write $WORKDIR/subgid.new /etc/subgid
rm /etc/default/locale
write $WORKDIR/default.locale /etc/default/locale
rm /etc/locale.gen
write $WORKDIR/locale.gen /etc/locale.gen
rm /etc/timezone
write $WORKDIR/timezone /etc/timezone
rm /etc/default/keyboard
write $WORKDIR/default.keyboard /etc/default/keyboard
rm /etc/default/console-setup
write $WORKDIR/console-setup /etc/default/console-setup
rm /etc/issue
write $WORKDIR/issue /etc/issue
rm /etc/rk3308bs-release
write $WORKDIR/rk3308bs-release /etc/rk3308bs-release
rm /etc/hostname
write $WORKDIR/hostname /etc/hostname
rm /etc/systemd/system/getty@.service.d/override.conf
rm /etc/systemd/system/serial-getty@.service.d/override.conf
rm /etc/systemd/system/serial-getty@.service.d/autologin.conf
rm /etc/systemd/system/serial-getty@ttyS3.service.d/baud1500000.conf
mkdir /etc/systemd/system/serial-getty@ttyS3.service.d
write $WORKDIR/serial-autologin.conf /etc/systemd/system/serial-getty@ttyS3.service.d/autologin.conf
rm /etc/profile.d/armbian-check-first-login.sh
rm /etc/profile.d/armbian-check-first-login-reboot.sh
rm /etc/systemd/system/multi-user.target.wants/armbian-firstrun.service
rm /etc/systemd/system/multi-user.target.wants/armbian-firstlogin.service
cd /etc/systemd/system
symlink /dev/null armbian-firstrun.service
symlink /dev/null armbian-firstlogin.service
unlink /etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service
symlink /dev/null armbian-resize-filesystem.service
mkdir /home/${USER_NAME}
set_inode_field /etc/shadow uid 0
set_inode_field /etc/shadow gid 42
set_inode_field /etc/shadow mode 0640
set_inode_field /etc/gshadow uid 0
set_inode_field /etc/gshadow gid 42
set_inode_field /etc/gshadow mode 0640
set_inode_field /etc/passwd mode 0644
set_inode_field /etc/group mode 0644
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
echo "Wrote $OUT (${IMAGE_TAG}: ${USER_NAME} autologin on ttyS3, passwords baked, shadow 0640)"
bash "$SCRIPT_DIR/tools/verify-rootfs-password.sh" "$OUT" "$ROOT_PASSWORD" || true

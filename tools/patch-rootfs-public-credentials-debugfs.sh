#!/usr/bin/env bash
# Public image bake via debugfs (no sudo): m1prox1/m1prox1, no WiFi.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="$SCRIPT_DIR/releases/1.0.0"
CONFIG="${CONFIG:-$SCRIPT_DIR/config.env.public.example}"
SRC="${1:-$REL/rootfs-v61.img}"
OUT="${2:-$REL/rootfs-v61-public.img}"

[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG"; exit 1; }
[[ -f "$SRC" ]] || { echo "Missing $SRC"; exit 1; }
# shellcheck source=/dev/null
source "$CONFIG"
USER_NAME="${USER_NAME:-m1prox1}"
USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
ROOT_PASSWORD="${ROOT_PASSWORD:?ROOT_PASSWORD required}"

cp -f "$SRC" "$OUT"
IMG="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

df_write() {
  local src="$1" dst="$2"
  debugfs -w -R "rm $dst" "$IMG" 2>/dev/null || true
  debugfs -w -R "write $src $dst" "$IMG" | tail -1
}

df_rm() { debugfs -w -R "rm $1" "$IMG" 2>/dev/null || true; }

ROOT_HASH="$(openssl passwd -6 "$ROOT_PASSWORD")"
USER_HASH="$(openssl passwd -6 "$USER_PASSWORD")"

debugfs -R "dump /etc/shadow ${STAGE}/shadow" "$IMG"
python3 - "$STAGE/shadow" "$USER_NAME" "$ROOT_HASH" "$USER_HASH" <<'PY'
import sys
path, user_name, root_hash, user_hash = sys.argv[1:5]
lines = open(path).read().splitlines()
out, seen = [], set()
uid_tail = ["0", "99999", "7", "", "", ""]
for line in lines:
    if not line or line.startswith("#"):
        out.append(line)
        continue
    parts = line.split(":")
    u = parts[0]
    if u != "root" and u != user_name:
        if len(parts) > 2:
            uid_tail = parts[2:]
        continue
    if u == "root":
        parts[1] = root_hash
        out.append(":".join(parts))
        seen.add(u)
    elif u == user_name:
        parts[1] = user_hash
        out.append(":".join(parts))
        seen.add(u)
if user_name not in seen:
    out.append(f"{user_name}:{user_hash}:{':'.join(uid_tail)}")
open(path + ".new", "w").write("\n".join(out) + "\n")
PY
df_write "${STAGE}/shadow.new" /etc/shadow
debugfs -w -R "set_inode_field /etc/shadow mode 0100640" "$IMG" 2>/dev/null || true

debugfs -R "dump /etc/passwd ${STAGE}/passwd" "$IMG"
python3 - "$STAGE/passwd" "$USER_NAME" "${USER_REALNAME:-M1 Pro X1 Operator}" <<'PY'
import sys
path, name, real = sys.argv[1:4]
lines = open(path).read().splitlines()
out, found = [], False
for line in lines:
    if not line or line.startswith("#"):
        out.append(line)
        continue
    parts = line.split(":")
    if parts[0] == "root":
        out.append(line)
        continue
    if parts[2] == "1000" and parts[0] != name:
        continue
    if parts[0] == name:
        found = True
        parts[4] = real
        parts[5] = f"/home/{name}"
        parts[6] = "/bin/bash"
        out.append(":".join(parts))
    else:
        out.append(line)
if not found:
    out.append(f"{name}:x:1000:1000:{real}:/home/{name}:/bin/bash")
open(path + ".new", "w").write("\n".join(out) + "\n")
PY
df_write "${STAGE}/passwd.new" /etc/passwd

debugfs -R "dump /etc/group ${STAGE}/group" "$IMG"
python3 - "$STAGE/group" "$STAGE/passwd.new" "$USER_NAME" <<'PY'
import sys
path, passwd_path, name = sys.argv[1:4]
drop = set()
for pl in open(passwd_path):
    pp = pl.split(":")
    if len(pp) > 2 and pp[2] == "1000" and pp[0] != name:
        drop.add(pp[0])

def dedupe_members(s):
    seen, out = set(), []
    for m in s.split(","):
        if not m or m in seen:
            continue
        if m in drop:
            continue
        if m == "xateesix":
            m = name
        seen.add(m)
        out.append(m)
    return ",".join(out)

lines = open(path).read().splitlines()
out, found_g = [], False
for line in lines:
    if not line or line.startswith("#"):
        out.append(line)
        continue
    parts = line.split(":")
    g = parts[0]
    if g in drop or g == "xateesix":
        continue
    if len(parts) > 3:
        parts[3] = dedupe_members(parts[3])
        if g == "sudo" and name not in parts[3].split(","):
            parts[3] = ",".join(filter(None, [parts[3], name]))
    if g == name and parts[2] == "1000":
        if found_g:
            continue
        found_g = True
    out.append(":".join(parts))
if not found_g:
    out.append(f"{name}:x:1000:")
open(path + ".new", "w").write("\n".join(out) + "\n")
PY
df_write "${STAGE}/group.new" /etc/group

for _sub in subuid subgid; do
  debugfs -R "dump /etc/$_sub ${STAGE}/$_sub" "$IMG" 2>/dev/null || continue
  python3 - "${STAGE}/$_sub" "$USER_NAME" <<'PY'
import sys
path, name = sys.argv[1:3]
lines = open(path).read().splitlines()
out, seen = [], False
for line in lines:
    if not line or line.startswith("#"):
        out.append(line)
        continue
    parts = line.split(":")
    if parts[0] == "xateesix":
        parts[0] = name
    if parts[0] == name:
        if seen:
            continue
        seen = True
    out.append(":".join(parts))
open(path + ".new", "w").write("\n".join(out) + "\n")
PY
  df_write "${STAGE}/${_sub}.new" "/etc/$_sub"
done

debugfs -w -R "mkdir /home" "$IMG" 2>/dev/null || true
debugfs -w -R "mkdir /home/${USER_NAME}" "$IMG" 2>/dev/null || true
debugfs -w -R "mkdir /home/${USER_NAME}/docs" "$IMG" 2>/dev/null || true
mkdir -p "${STAGE}/home/${USER_NAME}/docs"
bash "$SCRIPT_DIR/tools/patch-rootfs-public.sh" "$STAGE"
find "${STAGE}/home/${USER_NAME}" -type f | while read -r f; do
  df_write "$f" "/${f#${STAGE}/}"
done

df_chown() {
  local rel="$1" mode="${2:-}"
  debugfs -w -R "set_inode_field $rel uid 1000" "$IMG" 2>/dev/null || true
  debugfs -w -R "set_inode_field $rel gid 1000" "$IMG" 2>/dev/null || true
  [[ -n "$mode" ]] && debugfs -w -R "set_inode_field $rel mode $mode" "$IMG" 2>/dev/null || true
}

df_rm /home/xateesix
debugfs -w -R "rm /home/xateesix" "$IMG" 2>/dev/null || true

while IFS= read -r f; do
  rel="/${f#${STAGE}/}"
  if [[ -d "$f" ]]; then
    df_chown "$rel" 040755
  else
    df_chown "$rel" 0100644
  fi
done < <(find "${STAGE}/home/${USER_NAME}" | sort)

cat > "${STAGE}/system.cfg" <<'EOF'
# RK3308BS /boot/system.cfg - optional hostname, timezone, WiFi (reboot to apply).
check_interval=30
wlan=wlan0
# Published images: WiFi not pre-configured.
#hostname='m1prox1'
#TimeZone='America/New_York'
#WIFI_SSID='your-ssid'
#WIFI_PASSWD='your-password'
EOF
df_write "${STAGE}/system.cfg" /boot/system.cfg

cat > "${STAGE}/issue" <<EOF
RK3308BS Armbian v0.64.1-companion
Serial: ttyFIQ0 @ 1500000 - login: ${USER_NAME}
WiFi: not pre-configured (optional: /boot/system.cfg)
Image: /etc/rk3308bs-release

EOF
cp "${STAGE}/issue" "${STAGE}/motd"
cat > "${STAGE}/rk3308bs-release" <<EOF
RK3308BS_IMAGE=v0.64.1-companion
RK3308BS_USER=${USER_NAME}
RK3308BS_WIFI=
RK3308BS_LOCALE=${LOCALE:-en_US.UTF-8}
RK3308BS_TZ=${TIMEZONE:-America/New_York}
RK3308BS_ROOTFS_GROW=armbian-resize-filesystem
RK3308BS_LCD=480x272-rgb
RK3308BS_SYSTEM_CFG=/boot/system.cfg
EOF
df_write "${STAGE}/issue" /etc/issue
df_write "${STAGE}/motd" /etc/motd
df_write "${STAGE}/rk3308bs-release" /etc/rk3308bs-release

debugfs -w -R "rm /root/.not_logged_in_yet" "$IMG" 2>/dev/null || true
debugfs -R "dump /etc/shadow ${STAGE}/shadow.verify" "$IMG"
grep -q "^${USER_NAME}:" "${STAGE}/shadow.verify" || { echo "FAIL: no shadow entry for ${USER_NAME}"; exit 1; }
echo "Wrote $OUT (user=${USER_NAME}, WiFi cleared)"
#!/usr/bin/env bash
# Verify baked password hashes in a rootfs ext4 image.
set -euo pipefail
IMG="${1:?image path}"
PW="${2:-ztfalxtspv}"

TMP="$(mktemp)"
debugfs -R "dump /etc/shadow $TMP" "$IMG" >/dev/null

while IFS=: read -r user hash _; do
	[[ "$user" == root || "$user" == xateesix ]] || continue
	[[ -z "$hash" || "$hash" == "*" || "$hash" == "!"* ]] && { echo "$user: locked/empty"; continue; }
	setting="${hash%${hash#*\$*\$*\$*}}"
	# setting = everything through third $ inclusive
	setting=$(echo "$hash" | sed -E 's|^(\$[^$]+\$[^$]+\$).*|\1|')
	got=$(perl -e 'print crypt($ARGV[0], $ARGV[1])' "$PW" "$setting")
	if [[ "$got" == "$hash" ]]; then
		echo "$user: PASS"
	else
		echo "$user: FAIL (hash mismatch)"
	fi
done < "$TMP"
rm -f "$TMP"

debugfs -R "stat /etc/shadow" "$IMG" | grep -E "Mode:|User:|Group:"

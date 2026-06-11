#!/usr/bin/env bash
# Generate userpatches/firstboot.conf from config.env (Armbian non-interactive first boot).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${SCRIPT_DIR}/config.env"
OUT="${1:-${SCRIPT_DIR}/userpatches/firstboot.conf}"

[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG"; exit 1; }
# shellcheck source=/dev/null
source "$CONFIG"

USER_PASSWORD="${USER_PASSWORD:-$ROOT_PASSWORD}"
USER_NAME="${USER_NAME:-xateesix}"
USER_REALNAME="${USER_REALNAME:-$USER_NAME}"
LOCALE="${LOCALE:-en_US.UTF-8}"
TIMEZONE="${TIMEZONE:-America/Los_Angeles}"

mkdir -p "$(dirname "$OUT")"
cat >"$OUT" <<EOF
# Generated from config.env — copied to /root/.not_logged_in_yet at image build time.
# Armbian firstlogin reads these PRESET_* vars and skips interactive prompts.
PRESET_ROOT_PASSWORD="$ROOT_PASSWORD"
PRESET_USER_NAME="$USER_NAME"
PRESET_USER_PASSWORD="$USER_PASSWORD"
PRESET_DEFAULT_REALNAME="$USER_REALNAME"
PRESET_LOCALE="$LOCALE"
PRESET_TIMEZONE="$TIMEZONE"
PRESET_CONNECT_WIRELESS=0
PRESET_NET_CHANGE_DEFAULTS=0
EOF
chmod 600 "$OUT"
echo "Wrote $OUT"

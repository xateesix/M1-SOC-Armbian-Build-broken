#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REL="${REL:-/tmp/armbian-m1-build/releases/1.0.0}"
PACK="$REL/pack_input_v54"
WIN_USER_HOST="${WIN_USER_HOST:-john.X86@10.22.2.55}"
WIN_REPO="${WIN_REPO:-C:/Workspaces/Armbian-M1-SOC}"
WIN_REPO="${WIN_REPO//\//\\}"
WIN_DEST="${WIN_DEST:-${WIN_REPO}\\releases\\1.0.0\\pack_input_v54}"
WIN_SCRIPT="${WIN_SCRIPT:-${WIN_REPO}\\tools\\pack-v55-via-ssh.ps1}"

# Windows desktop pack trigger.
# Override with environment variables: WIN_REPO, WIN_DEST, WIN_SCRIPT, WIN_USER_HOST, REL.

if [[ ! -d "$PACK/Image" ]]; then
  echo "ERROR: missing $PACK — run finish-v55-on-server.sh first"
  exit 1
fi

if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$WIN_USER_HOST" "echo ok" 2>/dev/null; then
  echo "Windows SSH reachable; syncing pack_input_v54 to $WIN_DEST..."
  rsync -avz -e "ssh -o StrictHostKeyChecking=accept-new" "$PACK/" "$WIN_USER_HOST:$WIN_DEST/"
  ssh -o StrictHostKeyChecking=accept-new "$WIN_USER_HOST" \
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT" -SkipPull
else
  echo "Windows SSH unavailable ($WIN_USER_HOST)."
  echo "On desktop run:"
  echo "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"$WIN_SCRIPT\""
fi

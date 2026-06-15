#!/bin/bash
set -euo pipefail
REL=/tmp/armbian-m1-build/releases/1.0.0
PACK="$REL/pack_input_v54"
WIN_USER_HOST="john.X86@10.22.2.55"
WIN_DEST="C:/Workspaces/Armbian-M1-SOC/releases/1.0.0/pack_input_v54"

# Windows desktop 10.22.2.55: SSH port 22 is CLOSED (inbound). Pack is triggered from the desktop via pack-v55-via-ssh.ps1.

if [[ ! -d "$PACK/Image" ]]; then
  echo "ERROR: missing $PACK — run finish-v55-on-server.sh first"
  exit 1
fi

if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$WIN_USER_HOST" "echo ok" 2>/dev/null; then
  echo "Windows SSH reachable; syncing pack_input_v54..."
  rsync -avz -e "ssh -o StrictHostKeyChecking=accept-new" "$PACK/" "$WIN_USER_HOST:$WIN_DEST/"
  ssh -o StrictHostKeyChecking=accept-new "$WIN_USER_HOST" \
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Workspaces\\Armbian-M1-SOC\\tools\\pack-v55-via-ssh.ps1" -SkipPull
else
  echo "Windows SSH unavailable (10.22.2.55:22 closed)."
  echo "On desktop 10.22.2.55 run:"
  echo "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\\Workspaces\\Armbian-M1-SOC\\tools\\pack-v55-via-ssh.ps1"
fi

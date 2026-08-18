#!/usr/bin/env bash
# Local/build-host only — not exported to public repo.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO/config.env"
if [[ -f "$CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG"
fi
WEBHOOK="${DISCORD_WEBHOOK_URL:-${DISCORD_WEBHOOK:-}}"
[[ -n "$WEBHOOK" ]] || { echo "notify-discord: set DISCORD_WEBHOOK_URL in config.env or environment" >&2; exit 1; }
MSG="${1:-Cursor AI: task complete}"
curl -fsS -H "Content-Type: application/json" -d "{\"content\": \"${MSG}\"}" "$WEBHOOK" >/dev/null
echo "notify-discord: sent"

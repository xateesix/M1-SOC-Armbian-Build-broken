#!/usr/bin/env bash
set -euo pipefail
MSG="${1:-Cursor AI: task complete}"
WEBHOOK="https://discord.com/api/webhooks/1515772395624071278/V3EfBQJEK9QZivzRUoE7Za7Ubb9gp3pVlCGqQsNJmVaPuIYX_G401AmWJ_2B_VIYYvWc"
curl -fsS -H "Content-Type: application/json" -d "{\"content\": \"${MSG}\"}" "$WEBHOOK" >/dev/null
echo "notify-discord: sent"

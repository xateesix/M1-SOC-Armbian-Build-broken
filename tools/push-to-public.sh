#!/usr/bin/env bash
# Export sanitized tree to PUBLIC_REPO_URL. Private work stays on origin.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO/config.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"
PUBLIC_URL="${PUBLIC_REPO_URL:-}"
[[ -n "$PUBLIC_URL" ]] || { echo "Set PUBLIC_REPO_URL in config.env"; exit 1; }
EXPORT="$(mktemp -d "$REPO/.wsl-tmp/public-export.XXXXXX")"
trap 'rm -rf "$EXPORT"' EXIT
git clone --local "$REPO" "$EXPORT/repo"
cd "$EXPORT/repo"

remove_ignore_path() {
  local path="$1"
  [[ -z "$path" || "$path" =~ ^# ]] && return 0
  if [[ "$path" == *"*"* || "$path" == *"?"* ]]; then
    local f
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      git rm -rf --ignore-unmatch "$f" 2>/dev/null || rm -rf "$f"
    done < <(git ls-files "$path" 2>/dev/null || true)
    shopt -s nullglob
    for f in $path; do
      [[ -e "$f" ]] || continue
      rm -rf "$f"
    done
    shopt -u nullglob
    return 0
  fi
  git rm -rf --ignore-unmatch "$path" 2>/dev/null || rm -rf "$path"
}

while IFS= read -r path || [[ -n "$path" ]]; do
  remove_ignore_path "$path"
done < "$REPO/.public-export-ignore"

mapfile -t FILES < <(git ls-files)
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  sed -i \
    -e 's/ztfalxtspv/YOUR_PASSWORD/g' \
    -e 's/OurIOT/YOUR_WIFI_SSID/g' \
    -e 's/mNhTYTeh#p3LnRw^Ln*N3Vwi/YOUR_WIFI_PASSWORD/g' \
    -e 's/10[.]22[.][0-9.][0-9.]*/your-host/g' \
    -e 's|https://discord.com/api/webhooks/[^"'\'' ]*|DISCORD_WEBHOOK_URL_REDACTED|g' \
    "$f" 2>/dev/null || true
done
git add -A
git diff --cached --quiet || git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "Sanitized public export"
git remote remove public 2>/dev/null || true
git remote add public "$PUBLIC_URL"
git push public HEAD:main --force-with-lease
echo "Pushed sanitized export to $PUBLIC_URL"
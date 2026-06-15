#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEADER="${1:-/etc/update-motd.d/10-armbian-header}"
SNIP="$SCRIPT_DIR/artillery-motd-branding.snippet"
MARK_START="# --- Artillery product branding ---"
MARK_END="# --- Board name and version line ---"

[[ -f "$HEADER" ]] || { echo "Missing $HEADER"; exit 1; }
[[ -f "$SNIP" ]] || { echo "Missing $SNIP"; exit 1; }

TMP=$(mktemp)
awk -v start="$MARK_START" -v end="$MARK_END" -v snip="$SNIP" '
  $0 == start { skip=1; print start; while ((getline line < snip) > 0) print line; close(snip); print ""; next }
  skip && $0 == end { skip=0 }
  skip { next }
  { print }
' "$HEADER" > "$TMP"
mv "$TMP" "$HEADER"
chmod +x "$HEADER"
echo "Updated Artillery branding in $HEADER"
